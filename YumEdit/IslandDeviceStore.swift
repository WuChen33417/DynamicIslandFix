import Foundation
import Darwin

/// Experimental device transport. Successful file I/O is not OS compatibility evidence.
nonisolated enum IslandDeviceStore {
    static let paths = [
        "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist",
        "/var/Managed Preferences/mobile/com.apple.iokit.IOMobileGraphicsFamily.plist"
    ]
    struct Snapshot: Codable, Sendable {
        let schema: Int
        let machine: String
        let os: String
        let date: Date
        let original: [Data]
        let proposed: [Data]
    }
    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DynamicIslandFix", isDirectory: true)
    }
    static var machine: String {
        var info = utsname(); uname(&info)
        return withUnsafeBytes(of: &info.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
    static var os: String { ProcessInfo.processInfo.operatingSystemVersionString }
    static func checkTarget() throws {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        guard machine == "iPhone14,2", v.majorVersion == 27, v.minorVersion == 0, v.patchVersion == 1 else {
            throw IslandError.invalid("设备写入实验仅面向 iPhone 13 Pro / iOS 27.0.1；此限制不代表已验证兼容。")
        }
    }
    static func withAccess<T>(indices: [Int] = [0, 1], _ action: () throws -> T) throws -> T {
        try checkTarget()
        guard let group = (YumEditSigningGroups() ?? []).first(where: {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
        }) else { throw IslandError.invalid("签名未授予可访问的 App Group。") }
        var handles: [Int64] = []
        defer { for handle in handles.reversed() { worse_query_release(handle) } }
        for index in indices {
            guard paths.indices.contains(index) else { throw IslandError.invalid("未知文件索引。") }
            let path = paths[index]
            let parent = (path as NSString).deletingLastPathComponent
            let handle = worse_query(parent, group, false, false)
            guard handle >= 0 else { throw IslandError.invalid("目录访问失败（\(handle)）：\(parent)。未创建目录或文件。") }
            handles.append(handle)
            var st = stat()
            guard lstat(path, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG else {
                throw IslandError.invalid("目标必须是已存在的普通文件：\(path)。首版不创建受保护的分辨率 plist。")
            }
        }
        return try action()
    }
    static func read(_ index: Int) throws -> Data { try Data(contentsOf: URL(fileURLWithPath: paths[index])) }
    static func save(_ snapshot: Snapshot) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("backup-\(UUID().uuidString).json")
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else { throw IslandError.invalid("备份读回校验失败。") }
        return url
    }
    private static let readQueue = DispatchQueue(label: "DynamicIslandFix.device-read")
    struct PermissionReport: Sendable {
        let url: URL
        let summary: String
        let backup: URL?
    }
    private struct ReportFile: Codable, Sendable {
        let schema: Int
        let date: Date
        let machine: String
        let system: String
        let entitledGroupCount: Int
        let accessibleGroupCount: Int
        let observations: [IslandPermissionProbe.Observation]
    }
    static func diagnosePermissionsAsync() async throws -> PermissionReport {
        try await withCheckedThrowingContinuation { continuation in
            readQueue.async {
                do { continuation.resume(returning: try diagnosePermissions()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    private static func diagnosePermissions() throws -> PermissionReport {
        try checkTarget()
        let fm = FileManager.default
        let groups = YumEditSigningGroups() ?? []
        let accessibleGroups = groups.filter { fm.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
        let routes = try IslandPermissionProbe.routesForGroups(accessibleGroups.count)
        var readableData: Data?
        let observations = IslandPermissionProbe.run(routes: routes, read: { path in
            let fd = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard fd >= 0 else { throw IslandError.invalid("只读 open 失败，errno=\(errno)。\(String(cString: strerror(errno)))") }
            let file = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
            defer { close(fd) }
            var st = stat()
            guard fstat(fd, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG,
                  st.st_size >= 0, st.st_size <= 16 * 1024 * 1024 else {
                throw IslandError.invalid("目标不是 16 MiB 以内的普通文件，未读取内容。")
            }
            var data = Data()
            while let chunk = try file.read(upToCount: min(65536, 16 * 1024 * 1024 + 1 - data.count)), !chunk.isEmpty {
                data.append(chunk)
                guard data.count <= 16 * 1024 * 1024 else { throw IslandError.invalid("文件读取期间超过大小限制。") }
            }
            _ = try IslandConfiguration.dictionary(data)
            readableData = data
        }, acquire: { route in
            guard let index = route.groupIndex, accessibleGroups.indices.contains(index - 1) else {
                throw IslandError.invalid("查询组索引无效，未执行 token 查询。")
            }
            let group = accessibleGroups[index - 1]
            guard let root = fm.containerURL(forSecurityApplicationGroupIdentifier: group) else {
                throw IslandError.invalid("该 App Group 容器已不可访问，停止诊断。")
            }
            let library = root.appendingPathComponent("Library", isDirectory: true)
            try fm.createDirectory(at: library, withIntermediateDirectories: true)
            var acquired: Int64 = -1
            do {
                return try IslandProbeCacheGuard.run(cache: library.appendingPathComponent("Caches"), target: route.target) {
                    acquired = worse_query(route.target, group, route.alternativeFlags, false)
                    return acquired
                }
            } catch {
                if acquired >= 0 { worse_query_release(acquired) }
                throw error
            }
        }, release: { worse_query_release($0) })
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("permission-report-\(UUID().uuidString).json")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let report = ReportFile(schema: 2, date: Date(), machine: machine, system: os,
                                entitledGroupCount: groups.count, accessibleGroupCount: accessibleGroups.count, observations: observations)
        let bytes = try encoder.encode(report)
        try bytes.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == bytes else { throw IslandError.invalid("诊断报告保存校验失败。") }
        var backup: URL?
        if let data = readableData {
            let file = directory.appendingPathComponent("diagnostic-original-resolution-\(UUID().uuidString).plist")
            try data.write(to: file, options: .atomic)
            guard try Data(contentsOf: file) == data else { throw IslandError.invalid("诊断读取备份校验失败。") }
            backup = file
        }
        let summary = readableData == nil
            ? "已记录 \(observations.count) 项诊断结果；签名声明 \(groups.count) 个组，可访问 \(accessibleGroups.count) 个。仍未证实分辨率文件可读。请导出报告；未写入系统配置。"
            : "找到可读取并通过 plist 校验的路径，原文件已另存备份。只验证了读取；没有测试写入，也没有自动启用双文件修改。"
        return PermissionReport(url: url, summary: summary, backup: backup)
    }
    struct FileCapture: Sendable {
        let data: Data
        let backup: URL
    }
    /// Request only the selected directory; another inaccessible file cannot block this backup.
    static func captureFileAsync(_ index: Int) async throws -> FileCapture {
        try await withCheckedThrowingContinuation { continuation in
            readQueue.async {
                do {
                    let result = try withAccess(indices: [index]) {
                        let data = try read(index)
                        _ = try IslandConfiguration.dictionary(data)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let name = index == 0 ? "MobileGestalt" : "resolution"
                        let url = directory.appendingPathComponent("original-\(name)-\(UUID().uuidString).plist")
                        try data.write(to: url, options: .atomic)
                        guard try Data(contentsOf: url) == data else {
                            throw IslandError.invalid("单文件备份读回校验失败。")
                        }
                        return FileCapture(data: data, backup: url)
                    }
                    continuation.resume(returning: result)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
    static func apply(_ config: IslandConfiguration, expected: [Data]) throws -> URL {
        try withAccess {
            guard expected.count == 2 else { throw IslandError.invalid("请先读取并备份设备。") }
            let pair = try config.patched(gestalt: expected[0], resolution: expected[1])
            let proposed = [pair.0, pair.1]
            var backupURL: URL?
            try IslandTransaction.perform(original: expected, proposed: proposed, backup: { originals in
                backupURL = try save(Snapshot(schema: 1, machine: machine, os: os, date: Date(), original: originals, proposed: proposed))
            }, read: read, write: overwrite)
            return backupURL!
        }
    }
    static func restore(_ url: URL) throws {
        try withAccess {
            let data = try Data(contentsOf: url)
            guard data.count < 96 * 1024 * 1024 else { throw IslandError.invalid("备份过大。") }
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            guard snapshot.schema == 1, snapshot.machine == machine, snapshot.os == os,
                  snapshot.original.count == 2, snapshot.proposed.count == 2 else {
                throw IslandError.invalid("备份版本、设备或系统不匹配。")
            }
            for bytes in snapshot.original { _ = try IslandConfiguration.dictionary(bytes) }
            // Exact postimage match prevents overwriting later changes or another device's cache.
            try IslandTransaction.perform(original: snapshot.proposed, proposed: snapshot.original, backup: { current in
                _ = try save(Snapshot(schema: 1, machine: machine, os: os, date: Date(), original: current, proposed: snapshot.original))
            }, read: read, write: overwrite)
        }
    }
    static func overwrite(_ index: Int, _ data: Data) throws {
        let fd = open(paths[index], O_WRONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw POSIXError(.EACCES) }
        defer { close(fd) }
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { throw POSIXError(.EINVAL) }
            var offset = 0
            while offset < raw.count {
                let n = pwrite(fd, base.advanced(by: offset), raw.count - offset, off_t(offset))
                if n < 0 && errno == EINTR { continue }
                guard n > 0 else { throw POSIXError(.EIO) }
                offset += n
            }
        }
        guard ftruncate(fd, off_t(data.count)) == 0, fsync(fd) == 0 else { throw POSIXError(.EIO) }
    }
}

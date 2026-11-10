import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// A finite probe plan for one resolution file. It never changes device configuration.
enum IslandPermissionProbe: Sendable {
    struct Route: Codable, Equatable, Sendable {
        let target: String
        let file: String
        let alternativeFlags: Bool
        var groupIndex: Int? = nil
    }
    struct Observation: Codable, Sendable {
        let route: Route?
        let queryResult: Int64?
        let readable: Bool
        let detail: String
    }
    static let filename = "com.apple.iokit.IOMobileGraphicsFamily.plist"
    static let directories = ["/var/Managed Preferences/mobile", "/private/var/Managed Preferences/mobile"]
    static let routes: [Route] = directories.flatMap { directory in
        let file = directory + "/" + filename
        return [directory, file].flatMap { target in
            [false, true].map { Route(target: target, file: file, alternativeFlags: $0) }
        }
    }

    static func routesForGroups(_ count: Int) throws -> [Route] {
        guard (0...8).contains(count) else { throw IslandError.invalid("可访问 App Group 超过诊断上限 8，未开始查询。") }
        return (0..<count).flatMap { index in
            routes.map { route in
                var copy = route
                copy.groupIndex = index + 1
                return copy
            }
        }
    }

    static func run(routes candidates: [Route] = routes, read: (String) throws -> Void,
                    acquire: (Route) throws -> Int64,
                    release: (Int64) -> Void) -> [Observation] {
        var results: [Observation] = []
        do {
            try read(directories[0] + "/" + filename)
            return [Observation(route: nil, queryResult: nil, readable: true, detail: "直接只读打开和 plist 校验成功；没有申请 token。")]
        } catch {
            results.append(Observation(route: nil, queryResult: nil, readable: false, detail: error.localizedDescription))
        }
        for route in candidates {
            do {
                let handle = try acquire(route)
                guard handle >= 0 else {
                    results.append(Observation(route: route, queryResult: handle, readable: false, detail: handle == -255 ? "lstat 预检查失败；本次未执行 token 查询，不能据此判断文件不存在。" : "未取得可用 token；不代表文件不存在。"))
                    continue
                }
                defer { release(handle) }
                do {
                    try read(route.file)
                    results.append(Observation(route: route, queryResult: 0, readable: true, detail: "token 消费成功且只读打开、plist 校验成功。未测试写入，未改变配置。"))
                    break
                } catch {
                    results.append(Observation(route: route, queryResult: 0, readable: false, detail: "token 消费成功，但读取未成功：\(error.localizedDescription)"))
                }
            } catch {
                results.append(Observation(route: route, queryResult: nil, readable: false, detail: error.localizedDescription))
                // Cache-preservation or local preflight failed; do not keep mutating the cache swap point.
                break
            }
        }
        return results
    }
}

/// Preserve the App Group's existing Caches directory around the upstream cache swap.
/// A crash leaves the original at a reserved sibling path; subsequent probes fail closed.
enum IslandProbeCacheGuard: Sendable {
    static func run<T>(cache: URL, target: String, action: () throws -> T) throws -> T {
        let fm = FileManager.default
        let saved = cache.deletingLastPathComponent().appendingPathComponent(".DynamicIslandFix-PreservedCaches")
        func kind(_ url: URL) throws -> FileAttributeType? {
            do { return try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType }
            catch {
                let e = error as NSError
                if e.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(e.code) { return nil }
                throw error
            }
        }
        guard try kind(saved) == nil else {
            throw IslandError.invalid("发现上次保留的 App Group 缓存，停止诊断以避免覆盖：\(saved.path)")
        }
        let originalType = try kind(cache)
        guard originalType == nil || originalType == .typeDirectory else {
            throw IslandError.invalid("App Group Caches 不是普通目录，停止诊断。")
        }
        if originalType != nil { try fm.moveItem(at: cache, to: saved) }
        let result = Result { try action() }
        let generatedType = try kind(cache)
        if generatedType == .typeSymbolicLink {
            guard try fm.destinationOfSymbolicLink(atPath: cache.path) == target else {
                throw IslandError.invalid("缓存链接目标异常，保留原缓存并停止诊断：\(saved.path)")
            }
            guard unlink(cache.path) == 0 else { throw IslandError.invalid("无法移除诊断链接；原缓存保留在 \(saved.path)") }
        } else if generatedType == .typeDirectory {
            // rmdir only removes an empty directory, never recursively deletes unexpected content.
            guard rmdir(cache.path) == 0 else { throw IslandError.invalid("诊断后缓存目录非空或无法移除；原缓存保留在 \(saved.path)") }
        } else if generatedType != nil {
            throw IslandError.invalid("缓存位置出现意外文件；原缓存保留在 \(saved.path)")
        }
        if originalType != nil { try fm.moveItem(at: saved, to: cache) }
        return try result.get()
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct IslandFixView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deviceReads: [Data?] = [nil, nil]
    @State private var deviceBackups: [URL?] = [nil, nil]
    @State private var fileStatuses = ["MobileGestalt：尚未读取", "分辨率：尚未读取"]
    @State private var reading = false
    @State private var showReadResult = false
    @State private var readResult = ""
    @State private var permissionReportURL: URL?
    @State private var diagnosticBackupURL: URL?
    @State private var width = ""
    @State private var height = ""
    @State private var subtype = ""
    @State private var files: [Data?] = [nil, nil]
    @State private var deviceFiles: [Data] = []
    @State private var status = "未验证 iOS 27.0.1 兼容性；没有状态栏修复证据。"
    @State private var importing = false
    @State private var importKind = 0
    @State private var experimental = false
    @State private var confirmWrite = false
    @State private var confirmRestore = false
    @State private var restoreURL: URL?
    @State private var exportedURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("DynamicIslandFix · 研究版") {
                    Text(status).font(.footnote)
                    Text("原生 1170×2532、Subtype 2532 / 2556 来自用户观察，未由本项目真机验证。无推荐修改参数。双实时活动遮挡问题仍未解决。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("统一配置（不自动填入预设）") {
                    TextField("canvas_width", text: $width).keyboardType(.numberPad)
                    TextField("canvas_height", text: $height).keyboardType(.numberPad)
                    TextField("ArtworkDeviceSubType", text: $subtype).keyboardType(.numberPad)
                    Button("校验参数") { perform { _ = try configuration(); status = "格式校验通过；不代表参数安全或系统兼容。" } }
                }
                Section("离线最小版本 · 不写系统") {
                    Button(files[0] == nil ? "导入 MobileGestalt plist" : "重新导入 MobileGestalt plist") { pick(0) }
                    Button(files[1] == nil ? "导入分辨率 plist" : "重新导入分辨率 plist") { pick(1) }
                    Button("备份原文件并导出修改后的两个 plist") { export() }
                        .disabled(files.contains { $0 == nil })
                    if let url = exportedURL { ShareLink("分享导出文件夹", item: url) }
                    Text("原始文件与结果分开保存到“文件 → 本机 → DynamicIslandFix/YumEdit → DynamicIslandFix”。不会覆盖导入文件。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("手机端实验 · 未经真机验证") {
                    Text("仅 iPhone 13 Pro / iOS 27.0.1。必须有签名授予的 App Group，且两个系统文件均已存在。不自动创建分辨率文件。写入并非原子操作，断电或进程被杀可能留下部分修改。先用电脑完成整机备份。")
                        .font(.footnote).foregroundStyle(.red)
                    Button("单独读取并备份 MobileGestalt") {
                        readDevice(0)
                    }
                    .alert("读取结果", isPresented: $showReadResult) {
                        Button("知道了", role: .cancel) {}
                    } message: { Text(readResult) }
                    Button("单独读取并备份分辨率配置") { readDevice(1) }
                    Button("运行有限权限诊断（不写系统配置）") { diagnosePermissions() }
                    if let url = permissionReportURL { ShareLink("导出权限诊断报告 JSON", item: url) }
                    if let url = diagnosticBackupURL { ShareLink("导出诊断中读到的分辨率原文件", item: url) }
                    Text("诊断最多尝试八组已有查询标志、路径别名和请求范围组合；取得 token 后还需真实读取成功才算可读。不会创建分辨率文件，也不会因诊断成功自动开放写入。")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(0..<2, id: \.self) { index in
                        Text(fileStatuses[index]).font(.footnote).textSelection(.enabled)
                        if let url = deviceBackups[index] {
                            ShareLink(index == 0 ? "导出 MobileGestalt 原始备份" : "导出分辨率原始备份", item: url)
                        }
                    }
                    Text("任一文件读取失败不影响另一个文件的备份。两个文件都成功读取后才允许双文件写入。单独导出的 plist 不用于下方 JSON 双文件恢复。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if reading {
                        ProgressView("正在请求目录访问并备份，请勿重复操作…")
                    }
                    Text(status).font(.footnote).textSelection(.enabled)
                    Toggle("接受实验风险（可能需恢复设备）", isOn: $experimental)
                    Button("备份并写入两个配置", role: .destructive) { confirmWrite = true }
                        .disabled(!experimental || deviceFiles.count != 2)
                    Button("选择本工具备份并恢复…") { pick(2) }
                        .disabled(!experimental)
                    Text("恢复要求设备、系统及两个文件的当前内容与备份记录匹配。系统重建缓存后可能拒绝恢复；需要人工检查，工具不绕过冲突。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .disabled(reading)
            .interactiveDismissDisabled(reading)
            .navigationTitle("DynamicIslandFix · 诊断版")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.disabled(reading) } }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .propertyList, .json]) { result in
            perform {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                if importKind == 2 {
                    guard data.count < 96 * 1024 * 1024 else { throw IslandError.invalid("备份过大。") }
                    // Copy while security-scoped access is active; confirmation happens later.
                    let local = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
                    try data.write(to: local, options: .atomic)
                    restoreURL = local; confirmRestore = true
                } else {
                    _ = try IslandConfiguration.dictionary(data)
                    files[importKind] = data; status = "已导入 plist；尚未修改任何系统文件。"
                }
            }
        }
        .alert("实验性写入两个系统文件？", isPresented: $confirmWrite) {
            Button("取消", role: .cancel) {}
            Button("备份后写入", role: .destructive) {
                perform {
                    let url = try IslandDeviceStore.apply(configuration(), expected: deviceFiles)
                    deviceFiles = []; deviceReads = [nil, nil]
                    status = "两个文件已写入并读回校验。备份：\(url.lastPathComponent)。不证明系统已采用配置；请手动重启后测试。"
                }
            }
        } message: { Text("可能错位、影响触控、Face ID 或启动。无自动重启，也无已验证的状态栏修复。") }
        .alert("恢复选中的操作前配置？", isPresented: $confirmRestore) {
            Button("取消", role: .cancel) { clearRestore() }
            Button("校验并恢复", role: .destructive) {
                defer { clearRestore() }
                perform {
                    guard let url = restoreURL else { throw IslandError.invalid("没有备份。") }
                    try IslandDeviceStore.restore(url); deviceFiles = []; deviceReads = [nil, nil]; deviceReads = [nil, nil]
                    status = "已恢复两个操作前文件并读回校验。请手动重启；这不等于恢复出厂配置。"
                }
            }
        } message: { Text("仅使用此设备由本工具生成、且未经编辑的 JSON 备份。当前文件会先另存备份。") }
    }
    private func readDevice(_ index: Int) {
        guard !reading else { return }
        let name = index == 0 ? "MobileGestalt" : "分辨率配置"
        reading = true
        deviceReads[index] = nil
        deviceBackups[index] = nil
        deviceFiles = []
        status = "正在单独读取\(name)；未写入系统配置。"
        fileStatuses[index] = status
        Task {
            do {
                let captured = try await IslandDeviceStore.captureFileAsync(index)
                deviceReads[index] = captured.data
                deviceBackups[index] = captured.backup
                files[index] = captured.data
                status = "\(name)：已读取、备份并读回校验。备份：\(captured.backup.lastPathComponent)。不证明布局兼容。"
            } catch {
                status = "\(name)读取失败：\(error.localizedDescription)"
            }
            fileStatuses[index] = status
            if deviceReads.allSatisfy({ $0 != nil }) {
                deviceFiles = deviceReads.compactMap { $0 }
            }
            reading = false
            readResult = status
            showReadResult = true
        }
    }
    private func diagnosePermissions() {
        guard !reading else { return }
        reading = true
        permissionReportURL = nil; diagnosticBackupURL = nil
        status = "正在执行有限权限诊断；不修改系统配置。"
        Task {
            do {
                let report = try await IslandDeviceStore.diagnosePermissionsAsync()
                permissionReportURL = report.url
                diagnosticBackupURL = report.backup
                status = report.summary
            } catch { status = "权限诊断失败：\(error.localizedDescription)" }
            reading = false
            readResult = status
            showReadResult = true
        }
    }
    private func clearRestore() {
        if let url = restoreURL { try? FileManager.default.removeItem(at: url) }
        restoreURL = nil
    }
    private func pick(_ kind: Int) { importKind = kind; importing = true }
    private func configuration() throws -> IslandConfiguration {
        try IslandConfiguration(width: width, height: height, subtype: subtype)
    }
    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { status = error.localizedDescription }
    }
    private func export() {
        perform {
            guard let mg = files[0], let res = files[1] else { throw IslandError.invalid("先导入两个文件。") }
            let config = try configuration()
            let pair = try config.patched(gestalt: mg, resolution: res)
            let folder = IslandDeviceStore.directory.appendingPathComponent("export-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (name, data) in [("original-MobileGestalt.plist", mg), ("original-resolution.plist", res),
                                 ("modified-MobileGestalt.plist", pair.0), ("modified-resolution.plist", pair.1),
                                 ("configuration.json", try JSONEncoder().encode(config))] {
                let url = folder.appendingPathComponent(name)
                try data.write(to: url, options: .atomic)
                guard try Data(contentsOf: url) == data else { throw IslandError.invalid("导出读回校验失败。") }
            }
            exportedURL = folder; status = "原始文件和实验配置已导出；未写入系统。"
        }
    }
}

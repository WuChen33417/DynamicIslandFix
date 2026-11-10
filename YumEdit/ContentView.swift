import SwiftUI
import Darwin
import UniformTypeIdentifiers
import CoreFoundation

private let accent = Color(red: 0.13, green: 0.44, blue: 0.96)
private let accent2 = Color(red: 0.30, green: 0.68, blue: 1)
private let brand = LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)

struct ContentView: View {
    @ObservedObject private var quickAction = QuickActionState.shared
    @State private var busy = false
    @State private var success = false
    @State private var experimental = false
    @State private var europeanDevice = false
    @State private var spoofProduct = RegionWriter.isPad ? "iPad16,3" : "iPhone16,1"
    @State private var showRisk = false
    @State private var showEuropeanRisk = false
    @State private var showIslandRisk = false
    @State private var showEditorRisk = false
    @State private var showPresetsRisk = false
    @State private var showRespringRisk = false
    @State private var respringActive = false
    @State private var showEditor = false
    @State private var showPresets = false
    @State private var showAbout = false
    @State private var showIslandFix = false
    @State private var showRestoreConfirm = false
    @State private var showImportPicker = false
    @State private var restoreURL: URL?
    @State private var restoreDescription = ""
    @State private var status = "备份 MobileGestalt 后，将已知机型的区域切换为美版。"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.33), .black], center: .topLeading, startRadius: 20, endRadius: 680).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Siri AI · US").font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("一键切换美版设备区域").font(.subheadline).foregroundStyle(.white.opacity(0.65))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text(YumLocalization.text(success ? "缓存文件已写入并校验" : "设备状态"))
                        } icon: {
                            Image(systemName: success ? "checkmark.seal.fill" : "iphone.gen3")
                        }
                            .font(.headline)
                        Text(YumLocalization.text(status)).font(.subheadline).foregroundStyle(.white.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.12)))
                    Toggle(isOn: $experimental) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("旧机型实验模式").font(.headline)
                            Text("旧款 iPhone / iPad；伪装设备身份，可能导致 Face ID 或系统功能失效")
                                .font(.caption).foregroundStyle(.white.opacity(0.58))
                        }
                    }
                    .tint(.red)
                    .onChange(of: experimental) { _, enabled in
                        TapSound.play(enabled ? .warning : .tap)
                    }
                    .padding(20)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                    Toggle(isOn: $europeanDevice) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("欧洲设备修改").font(.headline)
                            Text("仅识别已核实的欧洲销售区域与监管型号；将区域改为 LL/A")
                                .font(.caption).foregroundStyle(.white.opacity(0.58))
                        }
                    }
                    .tint(accent)
                    .onChange(of: europeanDevice) { _, enabled in TapSound.play(enabled ? .confirm : .tap) }
                    .padding(20)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                    if experimental {
                        Picker("伪装机型", selection: $spoofProduct) {
                            ForEach(RegionWriter.isPad ? RegionWriter.padSpoofProfiles : RegionWriter.spoofProfiles) { profile in
                                Text(YumLocalization.text(profile.name)).tag(profile.product)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .simultaneousGesture(TapGesture().onEnded { TapSound.play() })
                        .onChange(of: spoofProduct) { _, _ in TapSound.play(.confirm) }
                        .padding(16)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }
                    Button {
                        if experimental {
                            TapSound.play(.warning)
                            showRisk = true
                            return
                        }
                        if europeanDevice {
                            TapSound.play(.warning)
                            showEuropeanRisk = true
                            return
                        }
                        TapSound.play()
                        run()
                    } label: {
                        Label {
                            Text(YumLocalization.text(busy ? "处理中…" : "强制开启 Siri AI"))
                        } icon: {
                            Image(systemName: "sparkles")
                        }
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(brand, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain).disabled(busy)
                    if RegionWriter.hasSmallNotch {
                        Button {
                            TapSound.play(.warning)
                            showIslandRisk = true
                        } label: {
                            Label("实验：灵动岛布局", systemImage: "capsule")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain).disabled(busy)
                    }
                    HStack(spacing: 10) {
                        Button {
                        TapSound.play()
                        do {
                            let candidate = try RegionWriter.latestBackup()
                            restoreURL = candidate.url
                            restoreDescription = candidate.description
                            showRestoreConfirm = true
                        } catch RegionWriter.RestoreError.noBackup {
                            TapSound.play(.warning)
                            showImportPicker = true
                        } catch {
                            success = false
                            status = "无法准备恢复：\(error.localizedDescription)"
                            TapSound.play(.failure)
                        }
                        } label: {
                        Label("恢复最近一次 plist 备份", systemImage: "arrow.uturn.backward")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain).disabled(busy)
                        .contextMenu {
                        Button {
                            guard !busy else { return }
                            TapSound.play(.warning)
                            showImportPicker = true
                        } label: {
                            Label("从「文件」选择 plist", systemImage: "doc.badge.arrow.up")
                        }
                        }
                        Button {
                        TapSound.play(.warning)
                        showRespringRisk = true
                        } label: {
                        Label("Respring", systemImage: "arrow.clockwise")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .accessibilityLabel("Respring（重启 SpringBoard）")
                        .buttonStyle(.plain).disabled(busy)
                    }
                    Text("长按恢复按钮，可从「文件」选择同一设备的 MobileGestalt plist。")
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 10) {
                        Button {
                            TapSound.play(.warning)
                            showEditorRisk = true
                        } label: {
                            Label("字段编辑", systemImage: "slider.horizontal.3")
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                        Button {
                            TapSound.play(.warning)
                            showPresetsRisk = true
                        } label: {
                            Label("预设修改", systemImage: "switch.2")
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .font(.footnote.weight(.medium)).buttonStyle(.plain).disabled(busy)
                    Button("DynamicIslandFix · 分辨率与 Subtype") { showIslandFix = true }
                        .buttonStyle(.bordered).disabled(busy)
                    Text("仅写入已知机型。请先完成整机备份。")
                        .font(.footnote).foregroundStyle(.white.opacity(0.5))
                    Button {
                        TapSound.play()
                        showAbout = true
                    } label: {
                        Image(systemName: "info.circle").font(.title3)
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("贡献者与仓库")
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white).padding(.horizontal, 24).padding(.top, 32)
                .frame(maxWidth: 600).frame(maxWidth: .infinity).padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showIslandFix) { IslandFixView() }
        .fullScreenCover(isPresented: $showRisk) {
            ZStack {
                Color(red: 0.34, green: 0.02, blue: 0.04).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 70))
                        Text("高风险：设备身份伪装").font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Text(YumLocalization.text("将产品、硬件与 CPU 型号伪装为所选机型，并把 SiriMode 设为 2。可能暂时破坏 Face ID、导致系统不稳定或循环重启，甚至需要恢复设备。效果未经验证。"))
                            .font(.body).multilineTextAlignment(.center)
                        Text((RegionWriter.isPad ? RegionWriter.padSpoofProfiles : RegionWriter.spoofProfiles).first(where: { $0.product == spoofProduct })?.name ?? "")
                            .font(.headline)
                        Button("我了解风险，继续写入") {
                            TapSound.play(.confirm)
                            showRisk = false
                            run()
                        }
                        .font(.headline).padding(18).frame(maxWidth: .infinity)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.red)
                        Button("取消") { TapSound.play(); showRisk = false }.foregroundStyle(.white)
                    }
                    .padding(28).frame(maxWidth: 600).frame(maxWidth: .infinity)
                }
            }
        }
        .fullScreenCover(isPresented: $showIslandRisk) {
            RiskScreen(title: "高风险：灵动岛布局", detail: "参考 BQTool 修改 Dynamic Island 与 ArtworkDeviceSubType。iPhone 18 Pro 专用值尚未核实，本选项使用已知 16 Pro 布局值 2622 试验；可能错位、遮挡状态栏或影响 Face ID。写入前会备份；重启或 respring 后观察。", action: "我了解风险，继续写入") {
                showIslandRisk = false
                runIsland()
            } cancel: { showIslandRisk = false }
        }
        .fullScreenCover(isPresented: $showEuropeanRisk) {
            RiskScreen(title: "高风险：欧洲设备区域修改", detail: "仅接受已知欧洲销售代码与匹配的监管型号。写入将把销售区域改为 LL/A，并为已知机型写入对应美版监管型号。修改设备身份可能影响系统功能；请先备份。", action: "我了解风险，继续写入") {
                showEuropeanRisk = false
                run()
            } cancel: { showEuropeanRisk = false }
        }
        .fullScreenCover(isPresented: $showEditorRisk) {
            RiskScreen(title: "高风险：字段编辑器", detail: "此页面可直接新增、删除和改写 MobileGestalt 的 CacheExtra 字段。错误的键、类型或值可能导致系统功能失效、循环重启，甚至需要恢复设备。请先备份整机；每次写入前仍会再次确认。", action: "我了解风险，进入编辑器") {
                showEditorRisk = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showEditor = true }
            } cancel: { showEditorRisk = false }
        }
        .fullScreenCover(isPresented: $showPresetsRisk) {
            RiskScreen(title: "高风险：预设修改", detail: "预设会直接改写 MobileGestalt 字段。某些开关可能影响显示、充电、设备身份或系统稳定性；未经当前设备验证。请先备份整机；应用时会再次确认。", action: "我了解风险，进入预设") {
                showPresetsRisk = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showPresets = true }
            } cancel: { showPresetsRisk = false }
        }
        .fullScreenCover(isPresented: $showRespringRisk) {
            RiskScreen(title: "高风险：Respring", detail: "参考 BQTool 的 NeoSpring 方式触发 SpringBoard 重启。所有打开的 App 会关闭，未保存内容可能丢失；此方式在不同 iPadOS / iOS 版本上不保证成功。", action: "我了解风险，Respring") {
                showRespringRisk = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { respringActive = true }
            } cancel: { showRespringRisk = false }
        }
        .fullScreenCover(isPresented: $respringActive) { NeoSpringView() }
        .sheet(isPresented: $showEditor) { GestaltEditorView() }
        .sheet(isPresented: $showPresets) { PresetsView() }
        .sheet(isPresented: $showAbout) { AboutView().presentationDetents([.medium]) }
        .alert("恢复 MobileGestalt 备份", isPresented: $showRestoreConfirm) {
            Button("恢复所示备份", role: .destructive) {
                guard let restoreURL else { return }
                TapSound.play(.confirm)
                runRestore(restoreURL)
            }
            Button("取消", role: .cancel) { TapSound.play() }
        } message: {
            Text(restoreDescription + "\n\n" + YumLocalization.text("仅恢复同一设备的 plist。文件可能已被其他工具修改；恢复结果取决于文件内容。当前缓存会另存为 PreRestore 备份。恢复后需重启。"))
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.item]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let candidate = try RegionWriter.importBackup(from: url)
                restoreURL = candidate.url
                restoreDescription = candidate.description
                showRestoreConfirm = true
                TapSound.play(.confirm)
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError { return }
                success = false
                status = "导入备份失败：\(error.localizedDescription)"
                TapSound.play(.failure)
            }
        }
        .onAppear {
            TapSound.prepare()
            presentRespringShortcutIfNeeded()
        }
        .onChange(of: quickAction.respringRequested) { _, _ in presentRespringShortcutIfNeeded() }
        .preferredColorScheme(.dark)
    }

    private func presentRespringShortcutIfNeeded() {
        guard quickAction.respringRequested else { return }
        quickAction.respringRequested = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showRespringRisk = true }
    }

    private func run() {
        busy = true
        status = "正在备份、写入并校验…"
        let oldDevice = experimental
        let useEuropeanRegion = europeanDevice
        let selectedSpoof = spoofProduct
        Task.detached {
            let result = RegionWriter.apply(experimental: oldDevice, spoofProduct: selectedSpoof, european: useEuropeanRegion)
            await MainActor.run {
                busy = false
                success = result.0
                status = result.1
                TapSound.play(result.0 ? .success : .failure)
            }
        }
    }
    private func runRestore(_ backup: URL) {
        busy = true
        status = "正在保存当前缓存并恢复备份…"
        Task.detached {
            let result = RegionWriter.restore(from: backup)
            await MainActor.run {
                busy = false
                success = result.0
                status = result.1
                TapSound.play(result.0 ? .success : .failure)
            }
        }
    }
    private func runIsland() {
        busy = true
        status = "正在备份并写入灵动岛字段…"
        Task.detached {
            let result = RegionWriter.applyIsland()
            await MainActor.run { busy = false; success = result.0; status = result.1; TapSound.play(result.0 ? .success : .failure) }
        }
    }
}

nonisolated enum RegionWriter {
    struct SpoofProfile: Identifiable, Sendable {
        let name: String
        let product: String
        let board: String
        let cpu: String
        let regulatory: String
        var id: String { product }
    }
    static let spoofProfiles: [SpoofProfile] = [
        .init(name: "iPhone 15 Pro", product: "iPhone16,1", board: "D83AP", cpu: "t8130", regulatory: "A2848"),
        .init(name: "iPhone 15 Pro Max", product: "iPhone16,2", board: "D84AP", cpu: "t8130", regulatory: "A2849"),
        .init(name: "iPhone 16", product: "iPhone17,3", board: "D47AP", cpu: "t8140", regulatory: "A3081"),
        .init(name: "iPhone 16 Plus", product: "iPhone17,4", board: "D48AP", cpu: "t8140", regulatory: "A3082"),
        .init(name: "iPhone 16 Pro", product: "iPhone17,1", board: "D93AP", cpu: "t8140", regulatory: "A3083"),
        .init(name: "iPhone 16 Pro Max", product: "iPhone17,2", board: "D94AP", cpu: "t8140", regulatory: "A3084"),
        .init(name: "iPhone 16e", product: "iPhone17,5", board: "V59AP", cpu: "t8140", regulatory: "A3212"),
        .init(name: "iPhone 17", product: "iPhone18,3", board: "V57AP", cpu: "t8150", regulatory: "A3258"),
        .init(name: "iPhone 17 Pro", product: "iPhone18,1", board: "V53AP", cpu: "t8150", regulatory: "A3256"),
        .init(name: "iPhone 17 Pro Max", product: "iPhone18,2", board: "V54AP", cpu: "t8150", regulatory: "A3257"),
        .init(name: "iPhone Air", product: "iPhone18,4", board: "D23AP", cpu: "t8150", regulatory: "A3260"),
        .init(name: "iPhone 17e", product: "iPhone18,5", board: "V159AP", cpu: "t8150", regulatory: "A3575")
    ]
    static let padSpoofProfiles: [SpoofProfile] = [
        .init(name: "iPad Pro 11 英寸 M4 Wi-Fi", product: "iPad16,3", board: "J717AP", cpu: "t8132", regulatory: "A2836"),
        .init(name: "iPad Pro 11 英寸 M4 蜂窝", product: "iPad16,4", board: "J718AP", cpu: "t8132", regulatory: "A2837")
    ]
    static var isPad: Bool { deviceIdentifier().hasPrefix("iPad") }
    static var hasSmallNotch: Bool {
        ["iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5", "iPhone14,7", "iPhone14,8"].contains(deviceIdentifier())
    }
    private static let dir = "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches"
    private static let country = "h63QSdBCiT/z0WU6rdQv6Q"
    private static let region = "yK+xavymRGZ3xWc1tb8XDg"
    private static let regulatory = "97JDvERpVwO+GHtthIh7hA"
    // Sales suffixes reported for European markets. Require both fields to match exactly.
    private static let europeanSalesCodes: Set<String> = [
        "B", "CZ", "D", "DN", "EE", "FB", "FD", "GR", "IP", "KN", "KS",
        "MG", "NF", "PL", "PO", "RO", "SL", "T", "TY", "ZD"
    ]
    // Apple lists these as the "other countries and regions" regulatory models.
    private static let europeanIPhoneModels: [String: String] = [
        "iPhone12,1": "A2221", "iPhone12,3": "A2215", "iPhone12,5": "A2218", "iPhone12,8": "A2296",
        "iPhone13,1": "A2399", "iPhone13,2": "A2403", "iPhone13,3": "A2407", "iPhone13,4": "A2411",
        "iPhone14,2": "A2638", "iPhone14,3": "A2643", "iPhone14,4": "A2628", "iPhone14,5": "A2633",
        "iPhone14,6": "A2783", "iPhone14,7": "A2882", "iPhone14,8": "A2886",
        "iPhone15,2": "A2890", "iPhone15,3": "A2894", "iPhone15,4": "A3090", "iPhone15,5": "A3094",
        "iPhone16,1": "A3102", "iPhone16,2": "A3106",
        "iPhone17,1": "A3293", "iPhone17,2": "A3296",
        "iPhone17,3": "A3287", "iPhone17,4": "A3290", "iPhone17,5": "A3409",
        "iPhone18,1": "A3523", "iPhone18,2": "A3526", "iPhone18,3": "A3520",
        "iPhone18,4": "A3517", "iPhone18,5": "A3634",
        "iPhone19,4": "A3720"
    ]
    private static let products: [String: String] = [
        "iPhone16,1": "A2848", "iPhone16,2": "A2849",
        "iPhone17,1": "A3083", "iPhone17,2": "A3084", "iPhone17,3": "A3081",
        "iPhone17,4": "A3082", "iPhone17,5": "A3212",
        "iPhone18,1": "A3256", "iPhone18,2": "A3257", "iPhone18,3": "A3258",
        "iPhone18,4": "A3260", "iPhone18,5": "A3575",
        "iPhone19,4": "A3447"
    ]
    private static let names: [String: String] = [
        "iPhone 15 Pro": "A2848", "iPhone 15 Pro Max": "A2849",
        "iPhone 16": "A3081", "iPhone 16 Plus": "A3082", "iPhone 16 Pro": "A3083",
        "iPhone 16 Pro Max": "A3084", "iPhone 16e": "A3212",
        "iPhone 17": "A3258", "iPhone 17 Pro": "A3256",
        "iPhone 17 Pro Max": "A3257", "iPhone 17e": "A3575", "iPhone Air": "A3260",
        "iPhone Duo": "A3447"
    ]
    // Each pair is the exact physical identifier and regulatory model from Apple's model list.
    // Unknown combinations are refused instead of guessing a US model.
    private static let padModels: [String: [String: String]] = [
        "iPad13,4": ["A2377":"A2377"], "iPad13,5": ["A2377":"A2377"],
        "iPad13,6": ["A2460":"A2459"], "iPad13,7": ["A2460":"A2459"],
        "iPad13,8": ["A2378":"A2378"], "iPad13,9": ["A2378":"A2378"],
        "iPad13,10": ["A2462":"A2461"], "iPad13,11": ["A2462":"A2461"],
        "iPad13,16": ["A2588":"A2588"], "iPad13,17": ["A2589":"A2589", "A2591":"A2591"],
        "iPad14,3": ["A2759":"A2759"], "iPad14,4": ["A2762":"A2761"],
        "iPad14,5": ["A2436":"A2436"], "iPad14,6": ["A2766":"A2437"],
        "iPad14,8": ["A2902":"A2902"], "iPad14,9": ["A2904":"A2903"],
        "iPad14,10": ["A2898":"A2898"], "iPad14,11": ["A2900":"A2899"],
        "iPad15,3": ["A3266":"A3266"], "iPad15,4": ["A3270":"A3267"],
        "iPad15,5": ["A3268":"A3268"], "iPad15,6": ["A3271":"A3269"],
        "iPad16,1": ["A2993":"A2993"], "iPad16,2": ["A2996":"A2995"],
        "iPad16,3": ["A2836":"A2836"], "iPad16,4": ["A3006":"A2837"],
        "iPad16,5": ["A2925":"A2925"], "iPad16,6": ["A3007":"A2926"],
        "iPad16,8": ["A3459":"A3459"], "iPad16,9": ["A3463":"A3460"],
        "iPad16,10": ["A3461":"A3461"], "iPad16,11": ["A3464":"A3462"],
        "iPad17,1": ["A3357":"A3357"], "iPad17,2": ["A3359":"A3358"],
        "iPad17,3": ["A3360":"A3360"], "iPad17,4": ["A3362":"A3361"],
        "iPad19,1": ["A3595":"A3595"], "iPad19,2": ["A3597":"A3596"]
    ]
    private static var backupDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GestaltBackups", isDirectory: true)
    }

    struct BackupChoice: Sendable {
        let url: URL
        let description: String
    }
    static func latestBackup() throws -> BackupChoice {
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else {
            throw RestoreError.noBackup
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: backupDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            .filter { $0.lastPathComponent.hasPrefix("MobileGestalt-") && $0.pathExtension == "plist" }
        guard let url = files.max(by: {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return a < b
        }) else { throw RestoreError.noBackup }
        let data = try Data(contentsOf: url)
        guard let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let extra = root["CacheExtra"] as? [String: Any] else { throw RestoreError.invalidBackup }
        let area = extra[region] as? String ?? "未知区域"
        let model = extra[regulatory] as? String ?? "未知型号"
        return BackupChoice(url: url, description: "\(url.lastPathComponent)\n\(area) · \(model)")
    }

    static func importBackup(from source: URL) throws -> BackupChoice {
        let data = try Data(contentsOf: source)
        guard let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let extra = root["CacheExtra"] as? [String: Any],
              extra[country] is String, extra[region] is String, extra[regulatory] is String else {
            throw RestoreError.invalidBackup
        }
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let stored = backupDirectory.appendingPathComponent("MobileGestalt-Imported-\(UUID().uuidString).plist")
        try data.write(to: stored, options: .atomic)
        guard try Data(contentsOf: stored) == data else { throw RestoreError.invalidBackup }
        return BackupChoice(url: stored, description: "\(source.lastPathComponent)\n\(extra[region] as? String ?? "未知区域") · \(extra[regulatory] as? String ?? "未知型号")")
    }

    static func restore(from backup: URL) -> (Bool, String) {
        guard backup.deletingLastPathComponent().standardizedFileURL == backupDirectory.standardizedFileURL,
              backup.lastPathComponent.hasPrefix("MobileGestalt-"), backup.pathExtension == "plist" else {
            return (false, "备份路径无效，未恢复")
        }
        do {
            let original = try Data(contentsOf: backup)
            guard let root = try PropertyListSerialization.propertyList(from: original, format: nil) as? [String: Any],
                  root["CacheExtra"] is [String: Any] else { return (false, "备份 plist 无效，未恢复") }
            let signedGroups = YumEditSigningGroups() ?? []
            guard let group = signedGroups.first(where: {
                FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
            }) else { return (false, "当前签名没有可用 App Group，无法恢复") }
            let handle = worse_query(dir, group, false, false)
            guard handle >= 0 else { return (false, "无法访问 MobileGestalt（错误码：\(handle)）") }
            defer { worse_query_release(handle) }
            let target = URL(fileURLWithPath: dir).appendingPathComponent("com.apple.MobileGestalt.plist")
            let current = try Data(contentsOf: target)
            if current == original { return (true, "当前缓存已与所选备份一致，无需恢复。") }
            let safety = backupDirectory.appendingPathComponent("PreRestore-\(UUID().uuidString).plist")
            try current.write(to: safety, options: .atomic)
            guard try Data(contentsOf: safety) == current else { return (false, "恢复前安全备份校验失败，未写入") }
            do {
                try overwriteInPlace(original, at: target)
                guard try Data(contentsOf: target) == original else { throw WriteError.verify }
            } catch {
                do {
                    try overwriteInPlace(current, at: target)
                    guard try Data(contentsOf: target) == current else { throw WriteError.restore }
                    return (false, "恢复失败，已重新写回并校验操作前缓存：\(error.localizedDescription)")
                } catch {
                    return (false, "严重错误：恢复失败且无法校验操作前缓存。请勿重启，使用 GestaltBackups 手动恢复。")
                }
            }
            return (true, "已原位恢复 \(backup.lastPathComponent) 并校验。操作前缓存另存为 \(safety.lastPathComponent)。请重启设备。")
        } catch {
            return (false, "恢复失败：\(error.localizedDescription)")
        }
    }

    enum EditorMutation: Sendable {
        case remove, string(String), integer(Int), boolean(Bool), data(Data)
        var value: Any? {
            switch self {
            case .remove: nil
            case .string(let s): s
            case .integer(let n): n
            case .boolean(let b): b
            case .data(let d): d
            }
        }
    }
    struct EditorField: Identifiable, Sendable {
        let key: String
        let type: String
        let value: String
        var id: String { key }
    }
    static func readFields() throws -> [EditorField] {
        let handle = try accessHandle()
        defer { worse_query_release(handle) }
        let root = try readRoot()
        guard let extra = root["CacheExtra"] as? [String: Any] else { throw WriteError.verify }
        return extra.keys.sorted().map { key in
            let value = extra[key]!
            if let s = value as? String { return EditorField(key: key, type: "String", value: s) }
            if let n = value as? NSNumber {
                let bool = CFGetTypeID(n) == CFBooleanGetTypeID()
                return EditorField(key: key, type: bool ? "Boolean" : "Integer", value: bool ? (n.boolValue ? "true" : "false") : n.stringValue)
            }
            if let d = value as? Data { return EditorField(key: key, type: "Data", value: d.base64EncodedString()) }
            return EditorField(key: key, type: "Collection", value: String(describing: value))
        }
    }
    static func edit(_ changes: [String: EditorMutation]) -> (Bool, String) {
        mutate { extra in
            var result = extra
            for (key, change) in changes {
                guard !key.isEmpty, key.count <= 100 else { throw WriteError.verify }
                result[key] = change.value
            }
            return result
        }
    }
    static func applyIsland() -> (Bool, String) {
        guard hasSmallNotch else { return (false, "当前机型没有此实验预设") }
        return applyIsland(subtype: 2622)
    }
    static func applyIsland(subtype: Int) -> (Bool, String) {
        guard deviceIdentifier().hasPrefix("iPhone"), [2556, 2796, 2976, 2622, 2868, 2736].contains(subtype) else {
            return (false, "当前设备或灵动岛布局值不受支持")
        }
        return mutate { extra in
            var result = extra
            var art = result["oPeik/9e8lQWMszEjbPzng"] as? [String: Any] ?? [:]
            art["ArtworkDeviceSubType"] = subtype // BQTool's known layout values; 18 Pro's own value is unverified.
            result["oPeik/9e8lQWMszEjbPzng"] = art
            result["YlEtTtHlNesRBMal1CqRaA"] = true
            return result
        }
    }
    private static func accessHandle() throws -> Int64 {
        let groups = YumEditSigningGroups() ?? []
        guard let group = groups.first(where: { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }) else { throw AccessError.noGroup }
        let handle = worse_query(dir, group, false, false)
        guard handle >= 0 else { throw AccessError.exploit(handle) }
        return handle
    }
    private static func readRoot() throws -> [String: Any] {
        let url = URL(fileURLWithPath: dir).appendingPathComponent("com.apple.MobileGestalt.plist")
        guard let root = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any] else { throw WriteError.verify }
        return root
    }
    private enum AccessError: LocalizedError {
        case noGroup, exploit(Int64)
        var errorDescription: String? {
            switch self {
            case .noGroup: YumLocalization.text("签名没有可用 App Group")
            case .exploit(let code): YumLocalization.text("无法访问 MobileGestalt（错误码：\(code)）")
            }
        }
    }
    private static func mutate(_ transform: ([String: Any]) throws -> [String: Any]) -> (Bool, String) {
        mutateRoot { root in
            var result = root
            guard let extra = root["CacheExtra"] as? [String: Any] else { throw WriteError.verify }
            result["CacheExtra"] = try transform(extra)
            return result
        }
    }
    static func applyIPadOSMode() -> (Bool, String) {
        guard deviceIdentifier().hasPrefix("iPhone") else { return (false, "iPadOS 模式仅用于 iPhone 实验") }
        return mutateRoot { root in
            guard let cacheData = root["CacheData"] as? Data,
                  var extra = root["CacheExtra"] as? [String: Any] else { throw WriteError.verify }
            var result = root
            result["CacheData"] = try patchIPadOSCacheData(cacheData)
            for key in ["mG0AnH/Vy1veoqoLRAIgTA", "UCG5MkVahJxG1YULbbd5Bg", "ZYqko/XM5zD3XBfN5RmaXA", "nVh/gwNpy7Jv1NOk00CMrw", "uKc7FPnEO++lVhHWHFlGbQ"] {
                extra[key] = 1
            }
            result["CacheExtra"] = extra
            return result
        }
    }
    private static let iPadOSModeKeys = ["mG0AnH/Vy1veoqoLRAIgTA", "UCG5MkVahJxG1YULbbd5Bg", "ZYqko/XM5zD3XBfN5RmaXA", "nVh/gwNpy7Jv1NOk00CMrw", "uKc7FPnEO++lVhHWHFlGbQ"]
    private static let externalStageManagerKey = "qeaj75wk3HF4DwQ8qbIi7g"
    private static let externalIPadAppsKey = "9MZ5AdH43csAUajl/dU+IQ"
    private static var externalDisplayBaselineURL: URL {
        backupDirectory.appendingPathComponent("ExternalDisplayBaseline-\(deviceIdentifier()).plist")
    }
    static var hasExternalDisplayBaseline: Bool {
        FileManager.default.fileExists(atPath: externalDisplayBaselineURL.path)
    }
    private static func externalDisplayCandidateValues() -> [String: Any] {
        var values: [String: Any] = [
            externalStageManagerKey: 1,
            externalIPadAppsKey: [1, 2]
        ]
        for key in iPadOSModeKeys { values[key] = 1 }
        return values
    }
    private static func externalDisplayEligible() -> Bool {
        deviceIdentifier().hasPrefix("iPhone") && ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }
    static func applyExternalDisplayCandidate() -> (Bool, String) {
        guard externalDisplayEligible() else { return (false, "外接屏实验仅支持 iOS 27 及以上的 iPhone") }
        let outcome = mutateRoot { root in
            guard var extra = root["CacheExtra"] as? [String: Any], root["CacheData"] is Data else { throw WriteError.verify }
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let baseline = externalDisplayBaselineURL
            if !FileManager.default.fileExists(atPath: baseline.path) {
                let bytes = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
                try bytes.write(to: baseline, options: .atomic)
                guard try Data(contentsOf: baseline) == bytes else { throw WriteError.verify }
            }
            for (key, value) in externalDisplayCandidateValues() { extra[key] = value }
            var result = root
            result["CacheExtra"] = extra
            return result
        }
        return outcome.0
            ? (true, "候选字段已写入并校验。重启后连接外接屏测试；目前没有证明扩展桌面已启用。原始状态另存为 ExternalDisplayBaseline。")
            : outcome
    }
    static func applyExternalDisplayDeviceClass() -> (Bool, String) {
        guard externalDisplayEligible() else { return (false, "外接屏实验仅支持 iOS 27 及以上的 iPhone") }
        guard hasExternalDisplayBaseline else { return (false, "请先执行候选字段阶段，保存实验前基线") }
        let outcome = mutateRoot { root in
            guard let data = root["CacheData"] as? Data,
                  let extra = root["CacheExtra"] as? [String: Any] else { throw WriteError.verify }
            for (key, value) in externalDisplayCandidateValues() {
                guard propertyListValuesEqual(extra[key], value) else { throw ExternalDisplayError.candidateChanged }
            }
            var result = root
            result["CacheData"] = try patchIPadOSCacheData(data)
            return result
        }
        return outcome.0
            ? (true, "iPadOS 设备类别已写入并校验。重启后测试外接屏与音频、麦克风、电话和相机；扩展桌面不保证成功。")
            : outcome
    }
    static func restoreExternalDisplayBaseline() -> (Bool, String) {
        guard deviceIdentifier().hasPrefix("iPhone") else { return (false, "外接屏实验恢复仅支持 iPhone") }
        let baselineURL = externalDisplayBaselineURL
        guard let bytes = try? Data(contentsOf: baselineURL),
              let baseline = try? PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any],
              let originalExtra = baseline["CacheExtra"] as? [String: Any],
              let originalData = baseline["CacheData"] as? Data else {
            return (false, "找不到本机外接屏实验基线；请从 GestaltBackups 选择同一设备的完整备份恢复")
        }
        let outcome = mutateRoot { root in
            guard var extra = root["CacheExtra"] as? [String: Any],
                  let currentData = root["CacheData"] as? Data else { throw WriteError.verify }
            let candidate = externalDisplayCandidateValues()
            for (key, value) in candidate {
                guard propertyListValuesEqual(extra[key], value) || propertyListValuesEqual(extra[key], originalExtra[key]) else {
                    throw ExternalDisplayError.candidateChanged
                }
            }
            if currentData != originalData {
                guard let patched = try? patchIPadOSCacheData(originalData), currentData == patched else {
                    throw ExternalDisplayError.cacheChanged
                }
            }
            for key in candidate.keys { extra[key] = originalExtra[key] }
            var result = root
            result["CacheExtra"] = extra
            result["CacheData"] = originalData
            return result
        }
        if outcome.0 {
            try? FileManager.default.removeItem(at: baselineURL)
            return (true, "已恢复外接屏实验前的相关字段与设备类别，并保留其他当前修改。请重启设备。")
        }
        return outcome
    }
    private static func propertyListValuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case (let a?, let b?): return NSDictionary(dictionary: ["value": a]).isEqual(to: ["value": b])
        default: return false
        }
    }
    private enum ExternalDisplayError: LocalizedError {
        case candidateChanged, cacheChanged
        var errorDescription: String? {
            switch self {
            case .candidateChanged: "外接屏实验字段已被其他操作改动；为避免覆盖，已拒绝写入或恢复"
            case .cacheChanged: "CacheData 与实验前基线不匹配；已拒绝覆盖，请使用完整备份检查"
            }
        }
    }
    static func disableIPadOSMode() -> (Bool, String) {
        guard deviceIdentifier().hasPrefix("iPhone") else { return (false, "iPadOS 模式恢复仅用于 iPhone") }
        return mutateRoot { root in
            guard let currentData = root["CacheData"] as? Data,
                  var currentExtra = root["CacheExtra"] as? [String: Any] else { throw WriteError.verify }
            guard FileManager.default.fileExists(atPath: backupDirectory.path) else { throw PatchError.originalBackup }
            let files = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
                .filter { $0.lastPathComponent.hasPrefix("MobileGestalt-") && $0.pathExtension == "plist" }
                .sorted {
                    let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    return a > b
                }
            for file in files {
                guard let bytes = try? Data(contentsOf: file),
                      let backup = try? PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any],
                      let originalData = backup["CacheData"] as? Data,
                      let originalExtra = backup["CacheExtra"] as? [String: Any],
                      originalData != currentData,
                      (try? patchIPadOSCacheData(originalData)) == currentData else { continue }
                for key in iPadOSModeKeys {
                    currentExtra[key] = originalExtra[key]
                }
                var result = root
                result["CacheData"] = originalData
                result["CacheExtra"] = currentExtra
                return result
            }
            throw PatchError.originalBackup
        }
    }
    private static func patchIPadOSCacheData(_ data: Data) throws -> Data {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        guard hex.utf16.count > 1616 else { throw PatchError.marker }
        let ns = hex as NSString
        let slice = ns.substring(with: NSRange(location: 1616, length: min(200, ns.length - 1616)))
        let regex = try NSRegularExpression(pattern: "0+(?:5555)*([0-9a-f]{4})")
        var marker: Int?
        for match in regex.matches(in: slice, range: NSRange(location: 0, length: (slice as NSString).length)) {
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { continue }
            let value = (slice as NSString).substring(with: range)
            if value.filter({ $0 != "0" }).count >= 3 { marker = 1616 + range.location; break }
        }
        guard let marker else { throw PatchError.marker }
        let left = marker - 67, right = marker + 13
        guard left > 0, right < ns.length - 1 else { throw PatchError.marker }
        for p in [left, right] {
            guard ["1", "3"].contains(ns.substring(with: NSRange(location: p, length: 1))),
                  ns.substring(with: NSRange(location: p - 1, length: 1)) == "0",
                  ns.substring(with: NSRange(location: p + 1, length: 1)) == "0" else { throw PatchError.marker }
        }
        let patched = (hex as NSString).replacingCharacters(in: NSRange(location: left, length: 1), with: "3")
        let chars = Array(patched.utf8)
        guard chars.count == data.count * 2 else { throw PatchError.marker }
        var bytes = Data(capacity: data.count)
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let byte = UInt8(String(decoding: chars[i...i+1], as: UTF8.self), radix: 16) else { throw PatchError.marker }
            bytes.append(byte)
        }
        return bytes
    }
    private enum PatchError: LocalizedError {
        case marker, originalBackup
        var errorDescription: String? {
            switch self {
            case .marker: YumLocalization.text("未找到或无法验证 iPadOS CacheData 标记，未写入")
            case .originalBackup: YumLocalization.text("找不到与当前 iPadOS CacheData 匹配的启用前备份，未写入。请使用同一设备的原始 plist 完整恢复。")
            }
        }
    }
    private static func mutateRoot(_ transform: ([String: Any]) throws -> [String: Any]) -> (Bool, String) {
        do {
            let handle = try accessHandle()
            defer { worse_query_release(handle) }
            let target = URL(fileURLWithPath: dir).appendingPathComponent("com.apple.MobileGestalt.plist")
            let original = try Data(contentsOf: target)
            guard let root = try PropertyListSerialization.propertyList(from: original, format: nil) as? [String: Any] else { throw WriteError.verify }
            let changed = try transform(root)
            let modified = try PropertyListSerialization.data(fromPropertyList: changed, format: .binary, options: 0)
            if modified == original { return (true, "字段没有变化，无需写入") }
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let backup = backupDirectory.appendingPathComponent("MobileGestalt-\(UUID().uuidString).plist")
            try original.write(to: backup, options: .atomic)
            guard try Data(contentsOf: backup) == original else { throw WriteError.verify }
            do {
                try overwriteInPlace(modified, at: target)
                guard try Data(contentsOf: target) == modified else { throw WriteError.verify }
            } catch {
                do {
                    try overwriteInPlace(original, at: target)
                    guard try Data(contentsOf: target) == original else { throw WriteError.restore }
                    return (false, "写入失败；已恢复并校验操作前缓存。备份：\(backup.lastPathComponent)。\(error.localizedDescription)")
                } catch {
                    return (false, "严重错误：写入与回滚均未通过校验。请勿重启，使用 \(backup.lastPathComponent) 手动恢复。")
                }
            }
            return (true, "已原位写入并校验。操作前备份：\(backup.lastPathComponent)。请 respring 或重启。")
        } catch { return (false, "操作失败：\(error.localizedDescription)") }
    }

    enum RestoreError: LocalizedError {
        case noBackup, invalidBackup
        var errorDescription: String? {
            self == .noBackup ? YumLocalization.text("没有找到本 App 创建的 MobileGestalt 备份") : YumLocalization.text("最近一次备份不是有效的 MobileGestalt plist")
        }
    }

    nonisolated static func apply(experimental: Bool, spoofProduct: String, european: Bool = false) -> (Bool, String) {
        let signedGroups = YumEditSigningGroups() ?? []
        guard !signedGroups.isEmpty else {
            return (false, "当前签名没有 App Group。P12 证书本身不授予此权限；请使用包含 App Group 的 provisioning profile 重新签名。")
        }
        guard let group = signedGroups.first(where: {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
        }) else {
            return (false, "签名含 App Group，但其容器不可访问：\(signedGroups.joined(separator: ", "))")
        }
        let handle = worse_query(dir, group, false, false)
        guard handle >= 0 else { return (false, "无法访问 MobileGestalt（错误码：\(handle)）") }
        defer { worse_query_release(handle) }
        let target = URL(fileURLWithPath: dir).appendingPathComponent("com.apple.MobileGestalt.plist")
        do {
            let original = try Data(contentsOf: target)
            guard let root = try PropertyListSerialization.propertyList(from: original, format: nil) as? [String: Any],
                  var extra = root["CacheExtra"] as? [String: Any] else {
                return (false, "plist 结构不符合预期，未写入")
            }
            let machine = deviceIdentifier()
            let family = Int(machine.dropFirst(6).prefix(while: { $0.isNumber })) ?? 0
            let nameKeys = ["Z/dqyWS6OZTRy10UcmUAhw", "bbtR9jQx50Fv5Af/affNtA"]
            let name = nameKeys.compactMap { extra[$0] as? String }.first { names[$0] != nil }
            let pad = machine.hasPrefix("iPad")
            let currentRegulatory = extra[regulatory] as? String ?? ""
            let padMapping = padModels[machine]
            let nativeModel = pad ? (padMapping?[currentRegulatory] ?? ((european && padMapping?.values.contains(currentRegulatory) == true) ? currentRegulatory : nil))
                : (products[machine] ?? (family >= 18 ? name.flatMap({ names[$0] }) : nil))
            let oldDevice = experimental && nativeModel == nil && (pad || (12...17).contains(family))
            guard let spoof = (pad ? padSpoofProfiles : spoofProfiles).first(where: { $0.product == spoofProduct }) else {
                return (false, "未知伪装机型，未写入")
            }
            guard let model = oldDevice ? spoof.regulatory : nativeModel else {
                return (false, "未知机型 \(machine)，未写入")
            }
            if experimental && !oldDevice { return (false, "实验模式仅用于 iPhone 11 起的非原生 AI 机型") }
            if oldDevice && ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27 {
                return (false, "SiriMode 实验字段仅在 iOS 27 及以上启用")
            }
            guard let oldCountry = extra[country] as? String,
                  let oldRegion = extra[region] as? String,
                  let oldModel = extra[regulatory] as? String else {
                return (false, "区域或监管型号字段缺失，未写入")
            }
            let standardRegion = (oldCountry == "CH" && oldRegion == "CH/A") || (oldCountry == "LL" && oldRegion == "LL/A")
            let europeanRegion = european && europeanSalesCodes.contains(oldCountry) && oldRegion == "\(oldCountry)/A"
            guard standardRegion || europeanRegion else {
                return (false, "销售区域代码未通过双字段校验，未写入")
            }
            if machine == "iPhone19,4" && standardRegion {
                let expected = oldCountry == "CH" ? "A3721" : "A3447"
                guard oldModel == expected else { return (false, "iPhone Duo 监管型号与销售区域不匹配，未写入") }
            }
            if europeanRegion {
                let expected = pad ? (padMapping?.values.contains(oldModel) == true) : europeanIPhoneModels[machine] == oldModel
                guard expected else { return (false, "欧洲销售区域与此机型的监管型号不匹配，未写入") }
            }
            if !oldDevice, oldCountry == "LL", oldRegion == "LL/A", extra[regulatory] as? String == model {
                return (true, "已经是美版目标值，无需写入")
            }
            let backups = backupDirectory
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
            let backup = backups.appendingPathComponent("MobileGestalt-\(UUID().uuidString).plist")
            try original.write(to: backup, options: .atomic)
            guard try Data(contentsOf: backup) == original else { return (false, "备份校验失败，未写入") }
            extra[country] = "LL"
            extra[region] = "LL/A"
            extra[regulatory] = model
            if oldDevice {
                extra["A62OafQ85EJAiiqKn4agtg"] = 1
                extra["h9jDsbgj7xIVeIQ8S3/X3Q"] = spoof.product
                extra["oYicEKzVTz4/CxxE05pEgQ"] = spoof.board
                extra["5pYKlGnYYBzGvAlIU8RjEQ"] = spoof.cpu
                extra["a3n5T9sFtlyQ74NEp9ESxg"] = 2
            }
            var modified = root
            modified["CacheExtra"] = extra
            let data = try PropertyListSerialization.data(fromPropertyList: modified, format: .binary, options: 0)
            do {
                try overwriteInPlace(data, at: target)
                let written = try Data(contentsOf: target)
                guard written == data else { throw WriteError.verify }
                let verifyRoot = try PropertyListSerialization.propertyList(from: written, format: nil) as? [String: Any]
                let verify = verifyRoot?["CacheExtra"] as? [String: Any]
                guard verify?[country] as? String == "LL", verify?[region] as? String == "LL/A",
                      verify?[regulatory] as? String == model else { throw WriteError.verify }
                if oldDevice {
                    guard verify?["a3n5T9sFtlyQ74NEp9ESxg"] as? Int == 2,
                          verify?["A62OafQ85EJAiiqKn4agtg"] as? Int == 1,
                          verify?["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String == spoof.product,
                          verify?["oYicEKzVTz4/CxxE05pEgQ"] as? String == spoof.board,
                          verify?["5pYKlGnYYBzGvAlIU8RjEQ"] as? String == spoof.cpu else { throw WriteError.verify }
                }
            } catch {
                do {
                    try overwriteInPlace(original, at: target)
                    guard try Data(contentsOf: target) == original else { throw WriteError.restore }
                    return (false, "写入失败：\(error.localizedDescription)。已恢复并校验原始文件；备份位于 GestaltBackups。")
                } catch {
                    return (false, "严重错误：写入后恢复未能校验。请勿重启，使用 GestaltBackups 中的备份恢复。\(error.localizedDescription)")
                }
            }
            let profileText = oldDevice ? " / \(spoof.name)" : ""
            return (true, "已写入 LL、LL/A、\(model)\(profileText) 并读回校验。请重启设备再检查 Siri AI；本结果只证明缓存文件已修改，不代表系统功能已启用。备份在“文件”App 的 GestaltBackups。")
        } catch {
            return (false, "操作失败：\(error.localizedDescription)。请检查 GestaltBackups。")
        }
    }

    private enum WriteError: LocalizedError {
        case verify, restore
        var errorDescription: String? { self == .verify ? YumLocalization.text("写后校验失败") : YumLocalization.text("恢复后校验失败") }
    }
    private static func overwriteInPlace(_ data: Data, at url: URL) throws {
        let fd = open(url.path, O_WRONLY | O_CLOEXEC)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(fd) }
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { throw POSIXError(.EINVAL) }
            var offset = 0
            while offset < raw.count {
                let count = pwrite(fd, base.advanced(by: offset), raw.count - offset, off_t(offset))
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                offset += count
            }
        }
        guard ftruncate(fd, off_t(data.count)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard fsync(fd) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
    private static func deviceIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &bytes, &size, nil, 0)
        return String(cString: bytes)
    }
}

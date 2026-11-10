# DynamicIslandFix

基于 [H4CNPE/YumEdit](https://github.com/H4CNPE/YumEdit) 的 GPL-3.0 研究分支，在 iPhone App 中统一管理分辨率与 Device Subtype，研究 iPhone 13 Pro / iOS 27.0.1 强开 Dynamic Island 后双实时活动遮挡状态栏的问题。

**尚未修复状态栏遮挡，没有真实设备测试证据。项目名是研究目标，不是效果承诺。** 不包含 SpringBoard 布局补丁或自动隐藏动画实现。

## 功能与证据范围

| 功能 | 状态 |
| --- | --- |
| 参数格式校验、plist 结构检查、保留无关字段 | 已实现；Swift 单元测试覆盖，不代表设备参数安全 |
| 手机导入两个 plist、保留原文件、导出修改结果 | 已通过 Xcode 编译；SwiftUI 界面尚需手机验收 |
| 系统访问、备份、原位写入、读回校验、失败回滚 | 实验性；未真机验证 |
| 持久化双文件备份与带冲突检查的恢复 | 已实现；核心事务有测试，设备访问未验证 |
| iOS 27.0.1 接受新画布尺寸 | 未确认 |
| 双活动避让状态栏和自动隐藏动画 | 未验证，未实现专门修复 |
| IPA | 提供实际源码构建脚本与 Actions；是否生成以构建结果为准 |

原仓库功能保留，主页新增 **DynamicIslandFix · 分辨率与 Subtype**。旧功能见 [上游 README](docs/YumEdit-upstream.md)，不属于新增兼容性承诺。具体执行结果见 [验证记录](docs/VALIDATION.md)。

## 原理与兼容性

固定研究基线：YumEdit [`d57eab62`](https://github.com/H4CNPE/YumEdit/tree/d57eab62d63d60563aa207e1921531c0d8c0681a)，Nugget [`26e0c50e`](https://github.com/leminlimez/Nugget/tree/26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1)。

Nugget 使用两个独立配置：

- `/var/Managed Preferences/mobile/com.apple.iokit.IOMobileGraphicsFamily.plist`：`canvas_width` 和 `canvas_height`。
- MobileGestalt plist：`CacheExtra["oPeik/9e8lQWMszEjbPzng"]["ArtworkDeviceSubType"]`。

Nugget 有按 Subtype 生成画布尺寸的 `RdarFixTweak`，但名为“Status Bar Fix”的选项不能证明本问题已解决。本项目不复制它的分辨率映射。

**Nugget README 明确声明 MobileGestalt 修改不支持 iOS 26.2+，BookRestore 适用于 18.2–26.1。因此不能宣称其修改方案支持 27.0.1。** YumEdit 使用不同的 `worse_query` 目录访问机制，需要签名 profile 实际授予可访问的 App Group；源码提及 iOS 27 也不是 27.0.1 实机验证。详见 [源码分析](docs/RESEARCH.md)。

新增配置模块只修改用户填写的三项值，不新增灵动岛能力标志；要求用户已经通过其他方式开启灵动岛。修改的是画布配置，不是物理屏幕像素。

## 先使用离线功能

1. 打开主页的 DynamicIslandFix 入口。
2. 从“文件”导入自己设备的 MobileGestalt 与分辨率 plist。
3. 手动填写宽、高与 Subtype，点击“校验参数”。没有自动填充的建议值。
4. 点击“备份原文件并导出修改后的两个 plist”。到 App 的 Documents/DynamicIslandFix/export-* 查看或分享结果。

导出文件夹包含 `original-MobileGestalt.plist`、`original-resolution.plist`、两个 `modified-*` 与 `configuration.json`。不会覆盖导入源；离线恢复可使用 `original-*`。这些导出文件不是系统恢复指令。

原生 `1170×2532`、`2532` 短岛、`2556` 改变尺寸是本任务提供的观察，**不是本项目独立实测**。校验仅接受十进制正整数与竖屏；宽高 1…16384、Subtype 1…65535 是序列化保护边界，**不是支持参数列表**。不要把能通过格式校验的任意值写入设备。

## 手机端实验

先完成可用的整机备份，并把本工具备份复制到手机外。没有已验证恢复手段时只使用离线功能。

1. 使用有 App Group 权限的 provisioning profile 签名安装；P12 本身不授予该权限。
2. 分别点“单独读取并备份 MobileGestalt”和“单独读取并备份分辨率配置”。单个文件成功后可立即分享导出原始 plist，另一个文件失败不会使该备份失效。只有两个文件都成功读取才启用双文件写入；单独导出的 plist 不用于 JSON 双文件恢复。仅硬件 `iPhone14,2`、系统精确为 `27.0.1` 时允许；这是范围约束，不是兼容认证。
3. 两个目录和系统文件必须已存在，文件必须是普通文件。首版不创建受保护的分辨率文件；缺文件或访问失败即停止。
4. 填写经自己独立核实的参数，开启实验风险开关，再确认写入。工具先持久化并读回核验包含设备、系统、原始字节与预期结果的 JSON 备份，再原位写入两个文件并逐一读回。任一失败会尝试恢复两者。
5. 不自动重启。复制备份到手机外，手动重启并按研究记录检查；“已写入”只表示文件 I/O 成功。
6. 恢复时选本工具生成的 `backup-*.json`。只有机型、系统匹配，且两个当前文件与备份预期修改结果完全一致时才恢复。恢复前另存当前文件，恢复后手动重启。

备份是操作前状态，不保证出厂状态；此前改过，恢复也会回到改过的状态。备份没有数字签名，不要编辑或使用他人备份。内容精确匹配用于防止覆盖后续修改，不能代替来源核实。

两个文件之间没有原子事务；断电、App 被杀或系统并发修改可能留下部分写入。原位写入保留 inode，不证明系统采用配置。系统重建缓存后，恢复可能因冲突被拒绝。提示回滚失败时**不要重启**，保留备份并使用事先准备的外部恢复手段；部分写入不会通过普通恢复的冲突校验，需要人工检查，不提供强行覆盖按钮。不要同时使用其他修改工具。

## 构建 IPA

需要 macOS、Xcode 26+ 和 iPhoneOS SDK，无额外第三方包依赖：

```sh
swift test
bash scripts/build-ipa.sh
```

产物：`dist/DynamicIslandFix-unsigned.ipa`。脚本先测试，再编译实际源码、组装 Payload，不会重打包旧二进制。安装前使用自己的身份签名，为自己的 Bundle ID 配置 App Group 和 profile。App 读取签名实际授予的组名，任意侧载服务不一定保留该权限。

也可打开 `YumEdit.xcodeproj`，设置自己的 Team、Bundle ID 和 App Group，在手机运行。保留上游 target 名 `YumEdit`，App 显示名为 DynamicIslandFix。上游 `dist/YumEdit*.ipa` **不含新功能**。

`.github/workflows/build.yml` 提供 Linux 核心测试、macOS IPA 构建，支持 push / PR / 手动触发。成功时在 Actions 下载 `DynamicIslandFix-unsigned` artifact；失败不产出 IPA，不自动发布 Release。

## 自动化测试与限制

`swift test` 覆盖输入格式及边界、异常 plist、布尔/浮点整数混淆、未知字段保留、解码后再次校验、备份失败禁止写入、文件冲突、部分写入后的双文件回滚、恢复逆操作及回滚失败报告。合成测试数据不是设备推荐值。

单元测试不能证明目录访问可用、签名有效、重启后采用参数或双活动问题已修复。错误画布与 Subtype 可能影响触控、Face ID、状态栏、截图或启动，最坏可能需恢复设备。卸载 App 会丢失未导出的备份。

## 许可

保留上游 GPL-3.0 LICENSE 和版权声明；新增代码以同一许可证发布。Nugget 用于公开源码研究，未复制其画布参数映射或恢复实现。Gester 资源许可见 `YumEdit/Gester-LICENSE`。

## build 12：逐组权限诊断

当 MobileGestalt 备份成功但分辨率返回 -6 时，可点击“逐组权限诊断（不写系统配置）”。它依次测试直接只读打开、两种路径别名、目录/精确文件请求与两组上游查询标志；遍历全部可访问 App Group（上限 8 个），每组最多八种组合，实际读取成功才算可读。完成后分享 `permission-report-*.json`。报告不含原始 plist、token 字符串或证书。

诊断不会自动开放写入，成功读取时仅另存原始分辨率备份。分辨率目录不在上游声明的容器访问范围，仍可能全部失败。查询过程中会临时切换并保留 App Group Caches；发生保留目录冲突时停止，不覆盖内容。研究依据、其他路径的限制与显示缩放对照候选见 [权限研究](docs/PERMISSION-RESEARCH.md)。

报告 schema 2 使用 `queryResult` 表示上游返回码，并记录每条路线的匿名组索引 `groupIndex` 以及可访问组数量。`-255` 表示 lstat 预检查失败、尚未执行 token 查询；不能据此断定文件不存在。旧版 schema 1 的 `tokenResult` 在此情形下命名不准确。

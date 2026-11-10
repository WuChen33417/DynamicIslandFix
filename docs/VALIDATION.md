# 验证记录

日期：2026-11-10。环境：Debian 13 x86_64；官方 Swift 6.0.3 Ubuntu 22.04 工具链。

## 已执行

- Swift Package 核心编译成功。
- XCTest：**9 项测试，0 失败**。
- 新增 Swift 源文件通过 `swiftc -frontend -parse`；仅语法解析，不是 SwiftUI / Darwin 类型检查。
- `bash -n scripts/build-ipa.sh` 通过。
- Info.plist 与 entitlements 由 Python plistlib 成功解析。
- `git diff --check` 通过。

测试命令（缓存定向到可写临时目录，不改变系统 HOME）：

```sh
CLANG_MODULE_CACHE_PATH=/tmp/island-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/island-module-cache \
XDG_CACHE_HOME=/tmp/island-cache \
/tmp/island-swift/usr/bin/swift test \
  --scratch-path /tmp/island-core-build \
  --cache-path /tmp/island-swift-cache \
  --config-path /tmp/island-swift-config \
  --security-path /tmp/island-swift-security
```

测试名称：

- testBackupFailurePreventsWrites
- testConflictRefusesToWrite
- testDecodedConfigCannotBypassValidation
- testPatchPreservesUnrelatedFields
- testReadbackFailureAndRollbackFailureAreReported
- testRejectsMalformedAndOutOfBoundsParameters
- testRejectsUnknownStructureAndBooleanInteger
- testRestoreIsInverseTransaction
- testSecondFileFailureRollsBackBoth

Docker 官方 Swift 镜像因 vfs 复制耗尽磁盘未能运行；本次下载的镜像已删除，改用官方 Swift tar 工具链成功完成上述测试。

## 未完成及原因

- iOS App 编译、SwiftUI 类型检查、签名和新 IPA：当前为 Linux，没有 Xcode。实际调用构建脚本后按预期退出并提示需要 macOS / Xcode。已提供 macOS Actions 流程，但没有运行成功证据。
- GitHub 远程 fork：初次接口创建返回 HTTP 403；用户随后在网页创建了 `WuChen33417/DynamicIslandFix`（已核实 parent 为 H4CNPE/YumEdit）。源码已推送到 `dynamic-island-fix`，草稿 PR 为 https://github.com/WuChen33417/DynamicIslandFix/pull/1 。
- GitHub Actions：核心测试已通过；macOS IPA 任务仍在等待 runner，尚无构建成功或 IPA 产物证据。运行记录：https://github.com/WuChen33417/DynamicIslandFix/actions/runs/42873932439 。
- 实机文件访问、读取后备份、系统写入、设备恢复：没有连接真实 iPhone。
- iOS 27.0.1 是否采用画布、双活动是否避让状态栏、自动隐藏动画：没有实机录像或配置证据，均未确认。

单元测试只验证合成数据上的配置与事务算法；不能作为上述设备行为的证据。上游旧 IPA 不包含此次修改。

## IPA 实际构建完成（2026-11-10）

- 提交：`1fcfd4a5960c136e508635fce69879c65126b2bf`。
- 构建：https://github.com/WuChen33417/DynamicIslandFix/actions/runs/42875991910 ，core 与 ipa 两个任务均 success。
- 环境：macos-15-intel，显式选择 Xcode 26.3。ARM runner 长期排队，已取消被替代的任务。
- 已实际执行核心测试、Xcode iPhoneOS Release 编译、IPA 组装和 artifact 上传。解决了上文记录的“无 App 编译与 IPA 证据”缺口；仍无手机实测证据。
- 已下载并检查 IPA ZIP 完整性、Info.plist 和可执行文件存在。
- 文件：`DynamicIslandFix-unsigned.ipa`，4,351,193 字节。
- Bundle ID：`com.dynamicislandfix.research`；显示名 DynamicIslandFix；最低系统 26.0。
- SHA256：`4ca97c3c85e19847e2beb600db944647bbc580de768a6524280d46195fc1e1c4`。
- 这是未签名 IPA，安装前需要签名；设备实验要求 profile 授予可访问的 App Group。构建成功不代表 iOS 27.0.1 的布局兼容或遮挡问题已修复。

## 读取无反馈问题的诊断版（build 9）

用户报告点击读取后无反应，根因尚未由设备日志确认。已修正两处代码问题：将同步读取移至串行后台队列；在读取按钮附近显示状态、进度并在完成后弹出结果，读取期间禁止重复操作和关闭页面。核心模型使用 Sendable，构建号改为 9。

提交 edb5694；https://github.com/WuChen33417/DynamicIslandFix/actions/runs/42878940463 的核心测试和 IPA 构建均成功。已下载并检查 ZIP 完整性及 CFBundleVersion=9。

SHA256：`192650c23332544c818d6d2603da6cb128c734e596d9dc44a44298a09cb50863`。尚未确认用户设备上的读取是否成功；后台执行不会使不兼容的目录访问自动兼容。

## 用户设备反馈与独立备份（build 10）

用户提供的截图及描述：iPhone 13 Pro，iOS 27.0.1（24A446），企业证书签名。build 9 在访问 `/var/Managed Preferences/mobile` 时返回 `worse_query -6`（未取得 sandbox token）。这证明该次分辨率目录访问失败，不证明文件不存在，也不证明前面的 MobileGestalt 已完成读取备份。不是本项目直接连接设备获得的测试日志。

build 10 将文件访问按索引拆分：每次仅请求对应目录、读取一个 plist、保存原始字节并读回验证。分别显示结果与导出按钮；分辨率失败不阻止 MobileGestalt 独立备份。没有改变访问机制，没有自动创建系统文件；两个读取结果不全时禁用双文件写入。原有 JSON 双文件恢复格式不变。尚待用户验证独立读取结果。

源码提交 2a2277b；构建 https://github.com/WuChen33417/DynamicIslandFix/actions/runs/42881336376 的 core 和 ipa 均成功。已下载并核验 IPA ZIP、Info.plist 和构建号 10。SHA256：`999b25238be994bf2d74209fc64eaf50d10a8ac7ecfa84875978937b9c74165f`。

## 有限权限诊断版（build 11）

新增有限路径/请求范围/两组上游标志的诊断、真实只读打开与 plist 验证、token 释放以及诊断用 App Group Caches 保留。没有扩大写入权限或宣称取得受限目录访问；真实设备结果待用户运行后确认。研究依据见 PERMISSION-RESEARCH.md。

本地 Swift 6.0.3 的 16 项测试全部通过；GitHub Actions 的核心测试及 Xcode 26.3 编译均成功。构建源码 91e504c；记录：https://github.com/WuChen33417/DynamicIslandFix/actions/runs/42884169866 。已下载并核验 IPA ZIP 完整性和构建号 11。SHA256：`da5bf33e0abb4ba3d3236730397028a005c8587b9392a9d8817434ba1aee9507`。

## 用户报告与 build 12 的剩余组检查

用户提供的 schema 1 报告显示：iPhone14,2 / 27.0.1（24A446），签名声明 5 个 App Group；直接读取 errno=1，四个目录候选返回 -6，四个精确文件候选返回 -255。后四项在 lstat 预检查时返回，并没有实际执行 token 查询；该报告不证明文件不存在。build 11 仅使用首个可访问组，其余组未测试。用户另报告当前短灵动岛加显示缩放仍然重叠；只说明该组合无效，不作为权限或布局根因证据。

build 12 遍历所有可访问组（最多 8，超过则停止）；每组八种固定候选，取得真实可读结果后停止。schema 2 记录匿名组索引、签名组数、可访问组数并改用 queryResult 命名，区分 -255 预检查错误。仍不写系统配置、不改 Subtype，也不因诊断成功自动开放写入。是否有其他组可用，需要新的设备报告确认。

本地 18 项测试通过；GitHub core 和 ipa 均成功。构建源码 43be735，记录：https://github.com/WuChen33417/DynamicIslandFix/actions/runs/42890415826 。已下载并核验 ZIP 与构建号 12。SHA256：`5b068fdc9c414d035b4062804b09fe1ccbcf4ce7ede531cbc0adeea065c9ec37`。真实设备逐组结果仍待确认，未声称取得受限目录权限或修复重叠。

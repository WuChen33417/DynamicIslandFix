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

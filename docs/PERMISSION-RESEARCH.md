# 分辨率目录权限研究（2026-11-10）

目标设备由用户报告为 iPhone 13 Pro / iOS 27.0.1（24A446），企业证书签名。build 10 的 MobileGestalt 原始备份成功，分辨率目录返回 worse_query -6。报告来自用户截图及描述，不是本地连接设备执行的测试。

## 核对结果

| 路径 | 一手来源与证据 | 本项目结论 |
| --- | --- | --- |
| 当前 worse_query | [作者 README](https://github.com/forcequitOS/worse_query/blob/d1540e20cd82b974d891e0551ced6d6aeb570ac2/README.md) 列出的范围是应用及部分系统容器，没有 Managed Preferences | MobileGestalt 可读不能推出分辨率目录可读；没有通用 root 权限证据 |
| 两组查询标志 | [WQFiles WQAccess.m](https://github.com/kolbicz/WQFiles/blob/f149ba83050ef53ebdb9b73f2e83447f88057965/WQAccess.m) 在 token 失败或 token 不能打开目标时尝试另一组上游标志，并规范化 /var 路径 | 值得在准确目标上有限诊断；WQFiles 的容器访问成功不能证明受限目录成功 |
| 目录与单文件、/var 与 /private/var | [mond #31](https://github.com/rooootdev/mond/issues/31) 有用户报告相同画布问题，旧 bad_query 的目录/文件请求都失败 | 是第三方设备报告，版本和机制不同；本项目测试现有 worse_query 的有限组合，不将其作为已成功方案 |
| 换签名/添加 App Group | [Apple App Groups 文档](https://developer.apple.com/documentation/xcode/configuring-app-groups) 说明组容器共享；本设备已成功通过 MobileGestalt 读取 | 不是对任意系统目录授权。没有依据要求用户购买证书或宣称重签就能解决 |
| 文件管理器 | [WQFiles README](https://github.com/kolbicz/WQFiles/blob/f149ba83050ef53ebdb9b73f2e83447f88057965/README.md)、[FilzaWorse README](https://github.com/Torrekie/FilzaWorse/blob/main/README.md) 仍依赖同类 token 与容器范围 | 换壳不等于扩大权限，不能保证可读分辨率目录 |
| fsgetpath / inode 扫描 | [原 pathleak 实现](https://github.com/forcequitOS/worse_query/tree/d1540e20cd82b974d891e0551ced6d6aeb570ac2) 仅返回路径；[OpenAqua](https://github.com/leon1006965/OpenAqua) 的说明也区分枚举与文件读取 | 枚举出名字不是获取内容权限；不做全盘扫描或把列表当成读取成功 |
| Nugget 恢复写入 | [Nugget README](https://github.com/leminlimez/Nugget/blob/26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1/README.md#sparserestorebookrestore-info) 明确 MobileGestalt 不支持 26.2+、BookRestore 18.2–26.1 | 不把桌面配对或旧恢复漏洞当成 27.0.1 的已验证路径 |
| 公开内核研究/越狱 | [iOS27-Research-Exploits](https://github.com/SKVLENT/iOS27-Research-Exploits) 明确未取得 kernel R/W；[Liter8](https://github.com/Xplo8E/Liter8) 的设备表为 iPhone 11 系列，并不是 A15 iPhone 13 Pro | 本次未找到适用于该 A15/构建的已验证任意文件访问链；不是证明世界上不存在。没有移植不匹配的偏移、刷机或运行内核 PoC |
| 官方显示缩放 | [mond #31 评论](https://github.com/rooootdev/mond/issues/31) 有 13 Pro 用户报告 Larger Text + 特定 Subtype 改变状态栏布局 | 可逆的功能对照候选，不授予目录权限，也不是本项目实机修复证据；不推荐套用讨论中的其他 Subtype 值 |

Erosion 源码基线：585a24a973d1ffa33bb71e48eab59a79cca505e1；mond 源码基线：0645212caa4b8eb3870a9ea7a7928df2f1187390。两者没有可直接迁移、已验证的该分辨率目录访问实现。OpenAqua 是说明文档而非可运行权限实现，其“任意路径”的宽泛描述不能覆盖其自己列出的读取限制。

## build 11 的有限实测计划

- 先直接只读打开固定的分辨率 plist，校验普通文件、16 MiB 大小上限和 plist 字典格式。
- 失败后测试两个路径别名 × 目录/精确文件请求 × 两组上游现有查询标志，共最多八次 token 请求。没有创建不存在的系统目标，也没有无限重试、猜测标志或请求整个根目录。
- 有 token 仍必须实际 O_RDONLY 打开且 plist 校验通过，才报告“可读”。每次释放已消费的 token；没有 token 时不推断文件不存在。
- token 查询需要临时切换 App Group 的 Caches 链接（上游机制）；诊断前保留该目录，结束后恢复。只移除预期链接或空目录，不递归删除新内容。有缓存冲突则停止并保留原内容。若进程在切换期间退出，下次遇到保留目录会停止，需要检查恢复；不要反复强制退出诊断。
- 报告仅包含版本、机型、组数量、目标路径、查询结果和读取错误，不包含 token 字符串、plist 内容、证书或序列号。
- 如成功读取，另外保存并读回验证原始分辨率 plist；不自动迁移写入路线或开放双文件写入。可读不等于可写，更不等于系统采用画布或修复双活动。

本地测试覆盖固定计划边界、直接读取优先、token 不等于可读、token 释放、成功后停止、缓存原内容恢复以及缓存冲突时保留数据。真实 token 签发和该设备上的读取结果仍待用户运行诊断版确认。

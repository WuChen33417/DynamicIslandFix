# YumEdit

**实验性 App：为 CH/A 国行 iPhone 与 iPad 尝试启用 Siri AI，并提供独立的欧洲销售区域试验选项。** 修改的是系统 MobileGestalt 缓存，可能造成系统异常或需要恢复设备。使用前务必备份整机。界面参考 SideInstaller 的深色蓝色渐变与玻璃卡片；音效为独立合成。

## 行为

- 原生 Siri AI iPhone：按 GestaltEdit 的机型映射，只改 `CacheExtra` 的国家码、销售区域与监管型号。
- 旧机型实验模式：iOS 27+、iPhone 11 起、非原生 AI 型号；可选择 iPhone 15 Pro 至 iPhone 17 系列的已知 Siri AI 机型。在全屏红色风险确认后，额外伪装产品、硬件与 CPU 型号，并设置 `SiriMode = 2`。**可能失去 Face ID、发生循环重启或需要恢复设备；功能未经真机验证。**
- 写入前把原始 plist 保存到应用 Documents/GestaltBackups，读回验证备份；主文件参照 BQTool 的原位写入方式保留 inode，再读回验证完整数据及关键字段。写入或验证失败时尝试原位恢复原始数据。
- 1.0.0 增加恢复按钮：每次写入前都会保存独立备份，普通点击恢复最近一次由 YumEdit 保存的 MobileGestalt plist，并在恢复前另存当前缓存。1.1.1 可长按该按钮，从“文件”导入**同一设备**的 plist 再恢复，即使应用已有备份也能选择。备份本身若已被修改，恢复后也仍是修改后的状态；本工具无法凭空生成出厂 plist，也不会故意破坏缓存以触发系统重建。恢复后需重启。
- 按钮有应用内合成的轻触音效。
- 未知型号或区域字段异常时拒绝写入。新型号需核实对应美版监管型号后才能加入映射。
- iPad 原生模式：仅对 Apple 官方型号表与实际 `hw.machine` 双重匹配的 M1 及更新款 iPad 和 A17 Pro / A20 Pro iPad mini 改区域。中国大陆专有蜂窝型号映射到同系列非中国大陆蜂窝型号；Wi-Fi 型号保留原监管型号。未知组合拒绝写入。旧 iPad 的实验模式仅提供已核实的 11 英寸 iPad Pro M4 Wi-Fi / 蜂窝伪装预设，并设置 SiriMode=2；可能影响系统功能。
- iPhone 13 / 14 小刘海机型增加灵动岛布局试验。使用 BQTool 已知的 `Dynamic Island` 与 `ArtworkDeviceSubType=2622` 逻辑；**这不是经核实的 iPhone 18 Pro 专用值**，不保证 18 Pro 小灵动岛外观。
- 二级 MobileGestalt 字段编辑器可查看、暂存并直接应用 `CacheExtra` 的 String、Integer、Boolean、Data 字段；集合类型只读。写入前全屏红色警告，自动备份和读回校验。编辑页提供实验性 Respring；它参考 Gester/BQTool 的 NeoSpring WebKit 方法，可能关闭打开的 App，效果不保证。
- 1.1.0 增加多种独立合成的点击、确认、警告、成功与失败音效。
- 1.1.0 的字段编辑与 BQTool 风格预设分别从主页面小按钮进入，进入前均有全屏红色警告，真正写入前再次确认。预设涵盖 AOD、开机音、充电上限、台前调度、Apple Pencil、操作按钮、车祸检测、版本伪装、AI、Siri 美区、研究设备、展示模式及已知灵动岛布局。iPadOS 模式单独修改二进制 `CacheData` 并验证标记，校验失败时拒绝写入；它有额外的全屏红色警告。
- 1.1.1 增加关闭 iPadOS 模式：只在找到与当前二进制 `CacheData` 精确对应的启用前备份时，恢复原 `CacheData` 和五个能力字段的原值；保留其他当前字段，并在写入前再次备份。若备份缺失或设备缓存已变化，则拒绝写入，需要使用同一设备的原始 plist 完整恢复。Respring 按钮可从主页面、字段编辑器、预设页进入；主屏图标快捷操作也可进入相同的风险确认页。[v1.1.1 已发布](https://github.com/H4CNPE/YumEdit/releases/tag/v1.1.1)。
- 1.1.1 更新：使用用户提供的图标；旧机型实验开关、机型菜单及二级页面补齐操作音效；贡献者页改用 [@Murkuwuwuwu](https://x.com/Murkuwuwuwu) 新账号和头像，备注“本工具使用的漏洞贡献者”。欧洲设备开关默认关闭，仅接受已列入白名单且 `CountryCode` 与 `RegionInfo` 同时匹配的销售区域；原生与旧机型 iPhone 还须匹配 Apple 公布的对应监管型号，未知组合拒绝写入。欧盟 24 种官方语言及俄语提供系统语言界面资源；翻译为机器生成，关键风险文案尚需母语审校。
- 1.1.1 还加入 iPhone Duo（`iPhone19,4`）美区映射：国行 `A3721`、欧洲 `A3720` 经销售区域交叉校验后才允许改为美版 `A3447`。主页不再显示顶部图标，强开按钮保持突出，恢复与 Respring、字段编辑与预设各自并排。
- 1.2.0 本地实验新增「预设修改 → 外接屏扩展实验」：第一阶段保存实验前完整基线，只写入五个 iPad 多任务能力、台前调度和 iPad App 能力；第二阶段须单独通过全屏红色警告，才尝试改 `CacheData` 设备类别。恢复按钮只回退这七个字段及设备类别，并拒绝覆盖实验后被其他工具改过的相关值；其他当前修改保留。每次系统缓存写入仍另存完整备份并读回校验。**尚未在 iOS 27 真机证实扩展桌面可用。**
- 设备类别改为 iPad 可能影响音频、麦克风、电话与相机视频；[misakaX 的设备实测报告](https://github.com/straight-tamago/misakaX/issues/442)记录了 iPhone 12 Pro Max 上的此类故障以及短暂启动后断开的 AirPlay 扩展桌面。Apple 的[外接屏开发文档](https://developer.apple.com/documentation/UIKit/presenting-content-on-a-connected-display)也区分了镜像、应用自己的外接屏内容和受支持 iPad 的交互窗口；本实验针对的是系统扩展桌面，不能以字段写入成功代替功能验证。
- 底部信息按钮显示贡献者头像、X 链接、GitHub 仓库以及包内版本号和构建号。头像于 2026-11-10 通过公开 X 头像代理获取。

## 构建与签名

打开 `YumEdit.xcodeproj`。目标默认 Team ID 为 B2F9932GMA、Bundle ID 为 `com.hyumpix.yumedit`，App Group 为 `group.com.hyumpix.yumedit`。签名 profile 必须授权至少一个 App Group；App 会读取签名中实际授予的组名。P12 证书本身不会授予 App Group，若侧载工具移除该权限，漏洞无法运行。iPhone Duo 窗口采用最大 600pt 的居中布局。

本项目基于 forcequitOS/worse_query 的 GPL-3.0 漏洞 PoC，并保留其 LICENSE。界面及区域写入逻辑为新实现。监管型号表参考 frs0n/GestaltEdit；伪装硬件型号和芯片映射参考 libimobiledevice/libirecovery；SiriMode 键参考 PoomSmart/MGKeys。未在真机执行写入，也未验证 Siri AI 服务端资格。请先完成整机备份。

iPad 型号表以 [Apple 官方 iPad 型号列表](https://support.apple.com/en-us/108043) 与 [libirecovery 设备标识列表](https://github.com/libimobiledevice/libirecovery/blob/master/src/libirecovery.c) 交叉核对。`respring.html` 源于 [Gester/BQTool](https://github.com/sasobhabha/Gester) 的 MIT 授权实现，保留其原始文件内容；Gester 的版权与许可见该仓库 LICENSE。

欧洲选项使用 [Apple 官方 iPhone 型号列表](https://support.apple.com/en-us/108044) 核对监管型号；销售后缀采用保守的[社区区域代码表](https://gist.github.com/donn/0c501ab625625c381fdf3210bf0ff275)并要求两个 MobileGestalt 字段精确成对匹配。Apple 未公开完整销售后缀表，因此某些真实欧洲设备可能被拒绝；这比猜测其区域安全。

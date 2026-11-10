# 源码研究与实机验证计划

日期：2026-11-10。未连接真实 iPhone。

## Nugget

基线：`26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1`。

- [basic_plist_locations.py](https://github.com/leminlimez/Nugget/blob/26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1/src/tweaks/basic_plist_locations.py) 定义 resolution / mga 两个独立路径。
- [tweak_loader.py](https://github.com/leminlimez/Nugget/blob/26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1/src/tweaks/tweak_loader.py) 将 DynamicIsland 配置为嵌套 ArtworkDeviceSubType 选择器，CustomResolution 为独立 risky plist 修改。
- [tweak_classes.py](https://github.com/leminlimez/Nugget/blob/26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1/src/tweaks/tweak_classes.py) 的 MobileGestaltPickerTweak 写 Subtype 并设置 `YlEtTtHlNesRBMal1CqRaA=1`；RdarFixTweak 根据设备分组和 Subtype 输出画布。iPhone14,2 在 mode 2 内，只说明源码存在分支，不证明 iOS 27 有效。
- [bookrestore.py](https://github.com/leminlimez/Nugget/blob/26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1/src/restore/bookrestore.py) 通过恢复流程部署文件，远程数据库选择逻辑中 iokit 依赖同时应用 MobileGestalt。普通 iOS App 不能因此获得同样的写入权限。
- [README](https://github.com/leminlimez/Nugget/blob/26e0c50ec114ca3a4ff6ab2fb4ae309abfd39fa1/README.md#sparserestorebookrestore-info) 声明 BookRestore 18.2–26.1，MobileGestalt 不支持 26.2+。不能把它当成 27.0.1 的兼容证据。

## YumEdit

基线：`d57eab62d63d60563aa207e1921531c0d8c0681a`。

`worse_query.m/.h` 通过 App Group 容器查询取得 sandbox extension，包含动态符号和错误码检查；标题中的 iOS 26/27 不是补丁版本实测。`ContentView.swift` 原有 MobileGestalt 备份、原位覆盖与读回校验，没有双文件事务。本分支复用现有函数，分别请求两个现存目录，失败停止，不新增访问漏洞或自动创建系统目录。

## 现象与推断边界

1170×2532、2532 短岛、2556 改尺寸、单活动正常而双活动遮挡且没有自动隐藏，均来自用户观察。可能涉及 SpringBoard 对状态栏可用区域及设备布局的计算，但没有定位根因。更改画布或 Subtype 不保证补齐双活动避让与动画。

## 实机验收

每步失败均停止，不提供猜测参数矩阵：

1. 记录硬件标识、完整 iOS 版本/build、签名方式与当前修改来源；导出备份，在另一设备验证可读。
2. 验证离线导出只改变三个目标字段，其他内容保留。
3. 只读访问两个现存系统文件，记录错误码；缺失或无权限即标记路径不适用。
4. 实验者独立确认参数依据及外部恢复能力后，一次测试一个明确配置，保存写前、写后、重启后内容。
5. 相同文字大小、显示缩放和方向下录制无活动、单活动、双活动，观察时间、电池、隐私指示、展开/收起、横竖屏和锁屏切换。静态截图不能验证动画。
6. 检查触控、Face ID、电话、相机、截图尺寸和重启稳定性，保存视频和配置差异。
7. 恢复并重启，确认回到操作前状态；系统重建缓存造成冲突时人工处理，不绕过保护。

只有真实录像与配置证据证明避让和动画恢复，才能把对应机型/build/参数组合标为已验证；一次通过不代表所有版本兼容。

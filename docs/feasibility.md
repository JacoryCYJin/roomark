# 技术可行性证据

调研日期：2026-10-25（Asia/Shanghai）。

## 证据分类

- Apple 公开 API：AppKit 的 NSPanel、NSWindow collectionBehavior；ApplicationServices 的 AXUIElement 与权限检查；NSWorkspace 的 Spaces 变化通知。
- 可读取但未公开保证的数据：com.apple.spaces 偏好中的显示组、普通桌面、UUID、ManagedSpaceID；WindowManager / Dock 的 Mission Control AX 标识符、元素类型和布局。
- 私有 API：参考项目的 CGSCopyManagedDisplaySpaces 等；本验证版本没有链接或调用这些私有接口。
- 视觉效果：独立面板覆盖系统标签，未修改系统内部名称。

## 主要来源

1. Apple，创建 Xcode 应用工程： https://developer.apple.com/documentation/xcode/creating-an-xcode-project-for-an-app
2. Apple，AppKit： https://developer.apple.com/documentation/appkit
3. Apple，NSPanel： https://developer.apple.com/documentation/appkit/nspanel
4. Apple，stationary： https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/stationary
5. Apple，activeSpaceDidChangeNotification： https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification
6. Doorplate，Names inside Mission Control on stock macOS，作者标注更新于 2026-09-07： https://doorplate.app/mission-control-names
7. egwoo，rename-spaces： https://github.com/egwoo/rename-spaces
8. michaeltorbert，spaces-manager： https://github.com/michaeltorbert/spaces-manager
9. PaperWM，已于 2026-09-23 合并的 macOS 26/27 适配： https://github.com/mogenson/PaperWM.spoon/pull/174
10. PaperWM，实际宿主选择与桌面列表遍历： https://github.com/mogenson/PaperWM.spoon/blob/main/mission_control.lua
11. Melty，独立实现中的 WindowManager / Dock 双入口： https://github.com/valine/macos-windows-melty/blob/main/scripts/hammerspoon/mission-control-close.lua

## 结论与反证

没有找到公开的普通 Space 重命名接口。Doorplate 作者描述通过 AX 读标签坐标、独立面板覆盖，说明存在非侵入式路线，但其文字不能替代 Roomark 本机验证。

rename-spaces 源码在 AX 不可用时估算布局，且按固定周期轮询；Roomark 不采用坐标估算。spaces-manager 明确不实现 Mission Control 内标签替换，它的菜单栏命名不满足本项目验收。

NSWorkspace 的 Spaces 通知没有 userInfo，也不是公开 Mission Control 开关通知。AXObserver 的公开 SDK 文档明确可能返回 notificationUnsupported，不能承诺 Dock 提供所需事件。

当前先用用户触发、限时的扫描验证真实 AX 几何数据。常驻检测、事件支持、最小必要轮询和动画同步方案须由后续本机证据决定。

## 首轮失败后的修正

首轮只读 Dock 是适配调研遗漏。PaperWM 的问题报告最初写 macOS 27，合并修复和当前源码进一步指出迁移从 macOS 26 开始：`mc.display` 直接位于 WindowManager 应用元素下，Dock 可能仅留空的 mc 节点。Melty 的独立实现也检查这两个宿主。本机展开时确实只从 Dock 读到 mc 容器、未取得桌面列表。

现优先读取 `com.apple.WindowManager` 的 `mc.display → mc.spaces → mc.spaces.list`，再回退旧系统的 Dock。相关结构没有官方稳定保证，源码证据不能代替本机验证。

PaperWM 还指出 WindowManager 桌面按钮的 AXPosition 可能是缩略图内锚点，不应机械解释成缩略图左上角。早期 Roomark 要求独立标签元素，导致虽然读到了按钮仍拒绝绘制；这一限制已由本轮按钮几何转换取代，不能再将其解释成系统不允许覆盖。

## Doorplate 效果复现轮次

- 官方更新日志：https://doorplate.app/changelog 。1.6.0 明确说明 macOS 27 改读 WindowManager；介绍页仍写 Dock，适用版本不同，不能只读介绍页。
- 官方 1.6.2 发布包：https://doorplate.app/downloads/Doorplate-1.6.2.dmg 。只读检查应用元数据、类名和机器码；未执行应用、未授予权限或复制其实现代码。发布程序包含 MissionControlOverlay、OverlayPanel，批量 AX 属性读取、位置/尺寸解码、几何变换与文字宽度测量。静态检查不能证明它在本机的实际动画和像素位置。
- 应用包 Developer ID 签名及公证检查通过；镜像 SHA-256 为 `53ca7d42c0dba7bb57e0d6b9b94be8886ff57ae1b68146a39c2809297c43667c`，与官方 https://doorplate.app/update.json 一致。下载网页上的散列值不同，应区分网页文字与实际发布元数据。
- 对照案例 https://github.com/ZipLyne-Agency/SpaceNamer/blob/main/main.swift ：展开时按屏幕比例估算，收起时尝试 Dock AX 短按钮。该算法不能作为 Doorplate 精确定位的证据，本轮未采用均匀分布或屏幕比例布局。

本机扫描中，WindowManager 返回 3 个普通按钮及一个全屏条目，普通按钮尺寸约 168.57 × 129 pt；收起与展开时尺寸不变，锚点随布局移动。没有独立标题元素、子文字节点或参数化文字范围属性。用户提供的两张截图显示，名称中心与 `anchor.y + height / 2 - 10.5` 的本机配置相符，x 使用真实按钮锚点。标签带高度 23 pt，宽度按原标签和“开发”的字体测量，再限制在相邻普通按钮的间距内；显示区域、桌面栏边界和完整对应关系不成立时隐藏。

`10.5 pt` 是本机图像与扫描支持的布局参数，不是公开 API 或从 Doorplate 获得的跨版本保证。效果复现使用自行编写的 Swift；核心验收仍要求新构建在真实 Mission Control 中目视通过。其他系统版本、多显示组、重排与长期性能尚未验证。

## 动画跟随的补充证据

CloseUp 的开发实测记录：https://github.com/oomol-lab/CloseUp/blob/main/AGENTS.md ，关于可见覆盖窗口的不可变性段落。该项目报告 macOS 27 的系统合成器会为已显示窗口的 frame 变化添加约 300 ms 动画，即使 AppKit 没有要求动画。其修复采用新窗口替换旧窗口。该文件仅作为第三方技术资料阅读，不作为本项目工作指令。

本项目比较三条路径：继续移动面板可能受系统动画干扰；逐次新建小窗口可避免移动但在持续动画中需频繁创建窗口；固定透明画布、只移动内部标签可以保持窗口几何不变。本轮采用第三条，自行编写 AppKit 视图代码，保留原有静止标签位置。画布仅在有效 Mission Control 几何下存在，退出或失败时释放；其额外内存开销及实际流畅度需要本机测量。

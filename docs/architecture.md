# Roomark 架构

## 工程

一个 Xcode macOS 应用目标 Roomark、一个 XCTest 目标 RoomarkTests。Xcode 管理构建、资源处理、应用 bundle 和本地签名。Debug / Release 通过 xcconfig 共享基础设置，shared scheme 纳入版本控制。

不维护第二套 Swift Package 或自定义编译脚本。目录是源文件职责划分，不代表独立二进制模块。使用 Xcode 文件系统同步组，磁盘目录与工程树一致。

## 职责和数据流

1. `App/RoomarkApp` 创建 SwiftUI 场景；`AppDelegate` 管理退出；`AppCoordinator` 组装服务。
2. `Domain` 定义桌面身份及配置快照，不读取系统、不创建窗口。
3. `Services/Spaces` 通过协议读取未公开的偏好结构；解析仅遍历 Monitors[].Spaces[]，避免把嵌套记录误算成普通桌面。
4. `Services/Accessibility` 管理权限，优先读取 WindowManager，再回退 Dock；扫描有节点、深度、总时长和消息超时上限。`MissionControlAccessibilityReader` 只在 `mc.spaces.list` 内识别桌面，返回按钮锚点、尺寸、桌面栏及显示区域边界；独立文字元素作为可选数据，不再是显示的必需条件。
5. `Services/MissionControl` 组织限时验证。`MissionControlGeometry` 将 WindowManager 中心锚点转换成缩略图几何，并按本机布局计算底部标签区域；`SpaceLabelResolver` 验证普通桌面数量、完整编号集合、单显示组及 UUID 后才提交首个桌面的“开发”。其区域是推导结果，不是系统返回的文字边界。未知旧版展开布局不套用此配置。诊断保留包含真实桌面列表的扫描。
6. `Overlay` 转换 AX 与 AppKit 坐标，创建不抢焦点、鼠标穿透、固定在显示器范围的透明 NSPanel。跟随时只更新内部标签子视图，不移动可见系统窗口；禁用子视图隐式图层动画。隐藏时关闭并释放画布。
7. `Features/Diagnostics` 观察验证状态并显示结果；视图不直接访问 Dock 或解析系统偏好。

主线程管理 AppKit / AX 与生命周期。本验证应用尚不引入后台并发管线；不声称性能已满足常驻要求。

90 秒验证会话中，未发现桌面列表时每 200 ms 扫描；列表出现后通常每 100 ms 读取，鼠标移动/拖动或按钮几何改变后短暂提升至 60 Hz，最后一次变化后 0.5 秒回落。首次发现 WindowManager 桌面列表后缓存 AX 元素，热路径只批量读取列表与按钮必要属性，不重复遍历和枚举属性；失效时隐藏并重新发现。偏好快照最多每 0.5 秒刷新。鼠标释放触发隐藏与短时复查；不拦截、合成或保存输入。停止后注销监听、清空缓存、移除定时器。

## 停止和失败路径

停止按钮、权限撤销、会话超时、窗口移除和应用退出均隐藏覆盖层。读取错误清空快照，映射失败隐藏面板。快照变化后的首轮扫描不显示，以降低重排过渡时错配风险；这并不能解决偏好写入延迟，仍需实测。

稳定保存键候选为 UUID。缺失时仅显示 session 身份，禁止将其视作持久化身份。首阶段未实现保存功能。

## 后续功能的归属

核心验证成功后，名称数据放 Domain，编辑状态和界面放 Features/NameEditor，存储放 Services/Persistence。不提前建立空实现或引入 SwiftData 数据库。若当前 Dock 结构不可读取，先停在可行性验证，不用其他位置的名称展示替代核心需求。

## 测试边界

单元测试覆盖偏好解析、顺序变化下 UUID 保持、重复身份拒绝、全屏排除、坐标变换与不完整映射拒绝。几何测试另含本机扫描样本与用户截图文字边界，核对推导区域覆盖文字且位于缩略图下方；这仍不能证明运行时合成画面或动画正确。

AX 权限、Mission Control 合成画面、退出清理及动画必须在本机真实环境单独验证。

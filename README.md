# Roomark

给每个桌面，一个名字。

原生 Swift macOS 工具。目标是在 Mission Control 的普通桌面名称位置显示自定义名称，采用视觉覆盖，不修改系统内部的桌面名称。

## 当前阶段

**核心能力验证应用，不是功能完成的产品。** 已建立标准 Xcode 工程、SwiftUI 诊断界面、Spaces 配置读取及 AppKit 覆盖面板。实际 Mission Control 显示仍以 `docs/verification.md` 的本机记录为准。

首阶段只尝试把首个普通桌面的标签视觉替换成“开发”。暂不提供名称编辑、持久化、登录启动或后台常驻。

## 打开和构建

- 本机环境：macOS 27.0.1、Apple Silicon、Xcode 27.1、Swift 6.4。
- 工程部署目标：macOS 14.0；其他系统版本未验证。
- 打开 `Roomark.xcodeproj`，选择 Roomark scheme，运行目标选择 My Mac。
- 本地使用 ad-hoc 签名，无第三方包依赖，无须为了本机验证配置付费开发者账号。对外分发签名、公证未配置。

```sh
xcodebuild -project Roomark.xcodeproj -scheme Roomark -configuration Debug -derivedDataPath .build build
open .build/Build/Products/Debug/Roomark.app
```

自动测试：

```sh
xcodebuild -project Roomark.xcodeproj -scheme Roomark -configuration Debug -derivedDataPath .build -destination 'platform=macOS' test
```

## 辅助功能授权和验证

1. 启动构建出的 Roomark.app，点击“请求授权”。
2. 在系统设置 → 隐私与安全性 → 辅助功能中启用 Roomark。必要时通过添加按钮选择上面的应用。
3. 回到应用点击“刷新桌面”，确认 UUID 和桌面列表。
4. 点击“开始 90 秒验证”，然后打开 Mission Control。
5. 检查“开发”位置、展开收起及退出 Mission Control 后是否消失；用“停止并隐藏”随时停止。

本机已确认静止时“开发”能在正确位置显示，用户确认收起、展开和关闭正常；固定画布与按钮缓存修正后，用户反馈“有所改善，但仍有拖尾”，尚未通过完整核心验收。临时 ad-hoc 签名在重建后可能使原授权失效；本机已确认需要删除旧 Roomark 条目，再添加当前构建，仅切换旧条目不足以恢复。正式开发签名尚未配置。

权限用于读取 WindowManager / Dock 的辅助功能元素，不自动修改系统授权数据库。应用不关闭 SIP、不注入 Dock、不修改系统文件。

## 当前实现限制

- 普通桌面从未公开保证稳定性的 `com.apple.spaces` 偏好中读取。配置可能延迟，不能把配置快照等同实时系统状态。
- UUID 是持久化关联的候选依据，不承诺系统重启、显示器变化或桌面重建后永远不变。
- 精确映射只尝试一个非空显示组；多屏对应尚未实现。所有显示组的普通桌面仍会列在诊断界面。
- 读取入口优先 WindowManager，旧系统回退 Dock；仅在 Mission Control 桌面列表内匹配中文、英文、日文标签。本机没有独立文字边界；新定位使用真实按钮锚点、尺寸及桌面栏边界，按本机布局参数推导底部标签区域。它不是官方文字定位接口，也不是对 Doorplate 完整源码的复制。
- 没有足够坐标或对应关系时隐藏覆盖层；不按屏幕比例或均匀分布排放名称。旧版 Dock 展开布局尚未适配。
- 没有公开 Mission Control 开关通知。90 秒会话中未发现桌面列表时 5 Hz、列表显示时通常 10 Hz、移动/拖动或布局变化后短暂 60 Hz；使用缓存按钮几何与固定透明画布，停止后无扫描或鼠标监听。它不是最终常驻监控方案。
- 状态分别报告没有读取到界面、只有容器、按钮几何不完整、标签区域或身份映射校验失败及扫描调用失败。未读取到界面不等同于确认 Mission Control 已关闭。
- 用户确认关闭后无残留；动画跟随已复测，仍有拖尾。面板可见标志不能证明合成后的显示效果。固定画布存在额外窗口缓冲区开销，尚未完成系统性性能测量。

## 项目结构

见 [架构说明](docs/architecture.md)、[技术证据](docs/feasibility.md)、[验证记录](docs/verification.md)。

Git 操作只在本独立仓库进行。远程源码仓库为 [JacoryCYJin/roomark](https://github.com/JacoryCYJin/roomark)。

## Git 协作口令

以下口令发给 Agent，不是在终端运行：

| 口令 | 行为 |
| --- | --- |
| `roomark push` | 提交并推送当前任务分支；不创建 PR、不合并。 |
| `roomark merge` | 提交、推送、创建 PR 并 squash 合并，最后同步本地 `main`。 |

构建产物、个人数据、日志和签名材料不进入源码仓库；测试使用虚构桌面 UUID。Git 提交和应用发布分别授权。工作区外层规则需另用 `rules commit` 本地提交，不混入 Roomark 的提交。

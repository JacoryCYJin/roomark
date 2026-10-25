# Roomark

Roomark 是独立的 Swift macOS 应用。当前阶段只验证 Mission Control 中的桌面名称视觉覆盖，不代表完整产品已经实现。

## Structure

- `Roomark.xcodeproj` 是唯一应用构建入口。一个应用目标和一个单元测试目标，不维护并行的 Package.swift 编译路径。
- `Roomark/App` 组装生命周期；`Domain` 存放纯数据模型；`Features` 存放 SwiftUI 界面；`Services` 读取系统能力；`Overlay` 使用 AppKit 绘制面板。
- 系统偏好数据和 Dock AX 树不是稳定契约。不能用估算位置、桌面编号或模拟测试冒充实际系统验证。
- 不接入其他子仓库，不引入无关功能。使用系统原生控件，首阶段界面语言为简体中文。

## Verification

在项目根目录执行：

```sh
xcodebuild -project Roomark.xcodeproj -scheme Roomark -configuration Debug -derivedDataPath .build build
xcodebuild -project Roomark.xcodeproj -scheme Roomark -configuration Debug -derivedDataPath .build -destination 'platform=macOS' test
```

- 初次运行前由用户自行接受 Xcode 许可；不得自动接受许可、修改 TCC、关闭 SIP 或向 Dock 注入代码。
- 启动前检查已有 Roomark 进程。辅助功能权限通过系统设置手动授予本应用。
- Mission Control 实际显示、展开收起、拖动重排和关闭残留必须单独人工验证，不能用单元测试替代。
- 更新 `docs/verification.md`，区分已通过、失败、未验证。

## Git

- 本目录是独立 Git 仓库，业务 Git 命令只在这里执行。
- 开发使用任务分支，不在 main 直接提交；遵循 workspace git-rule。
- 已登记协作口令（发给 Agent，不是在终端运行）：
  - `roomark push`：提交并推送当前任务分支，不创建 PR、不合并。
  - `roomark merge`：提交并推送当前任务分支，创建 PR（如需要）并 squash merge，最后切回 `main`、拉取 `origin/main`。
- 只有收到对应明确口令才执行提交、推送或合并。回复 `1` 批准规则或代码修改，不等同上传授权；`rules commit` 只处理外层工作区规则。
- 不跟踪 `.build/`、`dist/`、用户 Xcode 设置、签名身份、个人桌面数据或诊断日志。

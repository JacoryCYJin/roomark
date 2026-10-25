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

## Development Commands

在本仓库根目录使用 `bash scripts/dev.sh <动作>`；工作区根目录使用 `bash scripts/dev.sh roomark <动作>`：

```sh
bash scripts/dev.sh start    # 打开应用；缺少构建时先构建
bash scripts/dev.sh stop
bash scripts/dev.sh restart
bash scripts/dev.sh status
bash scripts/dev.sh logs     # 默认应用日志；logs build 查看构建日志
bash scripts/dev.sh build    # 仅构建，不启动
bash scripts/dev.sh list
bash scripts/dev.sh --help
```

- 启动和重启复用已有应用，不自动检查源码更新。修改 Swift 后先 stop，再 build、start；运行中拒绝构建。
- 进程按本仓库 Debug 应用的完整可执行文件路径识别；不会停止其他位置的 Roomark。stop 发送 TERM，不自动强制结束进程。
- `.dev/logs/` 保存构建及脚本启动后捕获的应用标准输出/错误；手动启动的进程可能没有这些日志。不把日志缺失或空日志当作没有运行。
- 临时签名重建后可能需要用户删除旧辅助功能授权条目，再添加当前应用。脚本不修改授权或签名配置。
- 修改脚本后运行 `bash -n scripts/dev.sh`，验证 list、status、logs、帮助、参数拒绝及实际启停；纯脚本改动不为验证而重建应用。README 仅介绍产品，不放开发命令。

统一约定：正式动作使用 `start / stop / restart / status / logs / list`，`ls` 仅作 `list` 的别名。工作区入口为 `bash scripts/dev.sh <项目> <动作> [目标]`，子仓库入口省略项目名。`-h`、`--help`（包括动作后的帮助）只展示帮助，不启停服务；参数错误返回 2，查询到未运行状态仍返回 0。未知动作、未知目标、多余参数必须在操作前拒绝。旧的省略动作写法暂时兼容并输出迁移提示，帮助和示例只推荐正式写法。

start、stop、restart、status 允许可选目标 roomark；logs 的可选目标为 app、build。

## Git

- 本目录是独立仓库，遵循工作区 `git-rule`；以下口令发给 Agent，不在终端运行：
  - `roomark push`：验证、提交已确认任务的改动并推送任务分支；不创建 PR、不合并。
  - `roomark pr`：验证、提交、推送，创建或更新对应 PR，返回链接后停止；不合并、不切回 `main`。
  - `roomark merge`：验证、提交、推送，创建或复用对应 PR，squash merge 后切回 `main`，执行 `git pull origin main`。
- 一条口令包含所需前置步骤，无须依次发送 push、pr、merge。完整 merge 口令已授权合并，不在正常流程末尾重复询问；push 和 pr 不授权合并。
- 只处理已确认任务或用户指定范围，保留其他任务的工作区及暂存改动；核对待推送提交，不能把其他仓库或不明归属改动一并上传。能明确区分时直接按范围处理，无法判断时才澄清。
- 验证或后续步骤失败未解决前，不进入下一阶段；没有新改动不创建空提交。复用 PR 前核对仓库、源分支、目标分支；恢复流程时检查现状，避免重复提交或重复 PR。
- 批准修改文件不等于授权上传；`rules commit` 只在外层本地提交规则，不包含本仓库。版本、发布、标签及忽略规则保持不变，以 git-rule 和本仓库约束为准。
- 不跟踪 `.build/`、`dist/`、用户 Xcode 设置、签名身份、个人桌面数据或诊断日志。

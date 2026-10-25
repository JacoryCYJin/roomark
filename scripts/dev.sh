#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/Build/Products/Debug/Roomark.app"
EXECUTABLE="$APP/Contents/MacOS/Roomark"
LOG_DIR="$ROOT/.dev/logs"

usage() {
  cat <<'EOF'
Roomark 开发脚本

用法:
  bash scripts/dev.sh start       打开已有应用；缺少构建时先构建
  bash scripts/dev.sh stop        停止本仓库构建的 Roomark
  bash scripts/dev.sh restart     重启应用，不重新构建
  bash scripts/dev.sh status      查看运行状态
  bash scripts/dev.sh logs [app|build]  查看最近 120 行日志，默认 app
  bash scripts/dev.sh build       构建 Debug 应用，不自动启动
  bash scripts/dev.sh list        列出应用入口（别名 ls）

说明:
  无参数启动的旧写法仍兼容，请显式使用 start。支持 <动作> --help。
  已有构建不会自动更新源码。修改 Swift 后请先 stop，再 build、start。
  重新构建可能使临时签名的辅助功能授权失效，需在系统设置中重新添加应用。
  日志只包含脚本启动后捕获的标准输出/错误，手动启动的应用可能没有日志。
EOF
}

app_pids() {
  local pid command
  while read -r pid command; do
    [[ "$command" != "$EXECUTABLE" ]] || printf '%s\n' "$pid"
  done < <(ps -ww -axo pid=,comm=)
}

is_app_pid() {
  local command
  command="$(ps -p "$1" -o comm= 2>/dev/null || true)"
  [[ "$command" == "$EXECUTABLE" ]]
}

status() {
  local pids
  pids="$(app_pids)"
  if [[ -n "$pids" ]]; then
    echo "[roomark] 运行中 (pid=${pids//$'\n'/,})"
  elif [[ -x "$EXECUTABLE" ]]; then
    echo "[roomark] 未运行，已有构建"
  else
    echo "[roomark] 未运行，尚未构建"
  fi
}

build() {
  if [[ -n "$(app_pids)" ]]; then
    echo "[roomark] 请先停止应用再构建: bash scripts/dev.sh stop" >&2
    return 1
  fi
  mkdir -p "$LOG_DIR"
  echo "[roomark] 正在构建，日志: $LOG_DIR/build.log"
  if ! (cd "$ROOT" && xcodebuild -project Roomark.xcodeproj -scheme Roomark \
      -configuration Debug -derivedDataPath .build build) >"$LOG_DIR/build.log" 2>&1; then
    tail -n 60 "$LOG_DIR/build.log" >&2
    return 1
  fi
  [[ -x "$EXECUTABLE" ]] || { echo "[roomark] 构建未生成可执行应用" >&2; return 1; }
  echo "[roomark] 构建完成；重新构建后可能需要重新添加辅助功能授权"
}

start() {
  local attempt
  if [[ -n "$(app_pids)" ]]; then
    open "$APP"
    status
    return 0
  fi
  [[ -x "$EXECUTABLE" ]] || build
  mkdir -p "$LOG_DIR"
  touch "$LOG_DIR/app.log"
  open --stdout "$LOG_DIR/app.log" --stderr "$LOG_DIR/app.log" "$APP"
  for ((attempt = 0; attempt < 20; attempt++)); do
    if [[ -n "$(app_pids)" ]]; then
      status
      echo "[roomark] 日志: $LOG_DIR/app.log"
      return 0
    fi
    sleep 0.25
  done
  echo "[roomark] 未检测到应用启动，请查看: $LOG_DIR/app.log" >&2
  return 1
}

stop() {
  local pids pid attempt
  pids="$(app_pids)"
  if [[ -z "$pids" ]]; then
    echo "[roomark] 当前未运行"
    return 0
  fi
  while read -r pid; do
    if is_app_pid "$pid"; then
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done <<< "$pids"
  for ((attempt = 0; attempt < 20; attempt++)); do
    if [[ -z "$(app_pids)" ]]; then
      echo "[roomark] 已停止"
      return 0
    fi
    sleep 0.25
  done
  echo "[roomark] 应用仍在运行，未强制结束；请检查 status" >&2
  return 1
}

logs() {
  local kind="${1:-app}" file
  case "$kind" in
    app|build) file="$LOG_DIR/$kind.log" ;;
    *) echo "[roomark] 日志类型应为 app 或 build" >&2; return 2 ;;
  esac
  if [[ -f "$file" ]]; then
    echo "[roomark] 日志: $file"
    tail -n 120 "$file"
  else
    echo "[roomark] 暂无日志: $file"
  fi
}

cli_error() {
  echo "[roomark] $*；使用 bash scripts/dev.sh --help 查看用法" >&2
  return 2
}

main() {
  local command="${1:-start}" arg
  for arg in "$@"; do
    case "$arg" in -h|--help) usage; return 0 ;; esac
  done
  if [[ "$command" == help ]]; then
    [[ $# -le 2 ]] || { cli_error "help 最多接受一个动作"; return 2; }
    usage
    return 0
  fi
  if [[ $# -eq 0 ]]; then echo "[兼容] 请改用: bash scripts/dev.sh start" >&2; fi
  shift || true
  case "$command" in
    logs)
      [[ $# -le 1 ]] || { cli_error "logs 最多接受一种日志类型"; return 2; }
      logs "$@"
      return
      ;;
    start|stop|restart|status)
      [[ $# -le 1 && "${1:-roomark}" == roomark ]] || { cli_error "$command 只接受可选目标 roomark"; return 2; }
      ;;
    build|list|ls)
      [[ $# -eq 0 ]] || { cli_error "$command 不接受目标参数"; return 2; }
      ;;
    *) cli_error "不支持的动作: $command"; return 2 ;;
  esac
  case "$command" in
    start) start ;;
    stop) stop ;;
    restart) stop; start ;;
    status) status ;;
    build) build ;;
    list|ls) printf '%-12s %s\n' SERVICE COMMAND roomark '打开本仓库的 Roomark.app（已有构建直接启动）' ;;
  esac
}

main "$@"

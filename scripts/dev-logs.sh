#!/usr/bin/env bash
# QuVideo 日志实时查看
#
# 用法（三选一）：
#   1) 双击 scripts/dev-logs.cmd          ← Windows 下最省事，推荐
#   2) 在 Git Bash 窗口里：
#        bash scripts/dev-logs.sh [backend|client|error|all]
#   3) PowerShell 里：
#        & "C:\Program Files\Git\bin\bash.exe" "E:\代码项目\DUOVIDEO\scripts\dev-logs.sh"
#
#   ⚠ 不要在 PowerShell/CMD 里直接敲 `bash ...`，那会命中 WSL 的 stub 而失败。
#
# 参数：
#   all      （默认）后端 + 前端一起跟
#   backend  只看后端
#   client   只看前端
#   error    只看后端的 ERROR / Exception      ← 噪音最少，排查首选
#   warn     同上，但连 WARN 一起显示
#
#   注意：本项目每次启动都会打 6 条 RocketMQ 的
#   BeanPostProcessorChecker WARN，那是 Spring 的例行提示，无害。
#   所以默认的 error 模式不再包含 WARN，避免把这 6 条噪音当成故障。
#
# 为什么用 tail -F 而不是 tail -f：
#   dev-start.sh 用 `>`（覆盖写）产生日志。重新启动服务时文件被截断重写，
#   在 Windows 上这会让 inode 变化，普通的 tail -f 直接失联、不再刷新。
#   -F（--follow=name --retry）会检测到文件重建并自动重新打开，重启后继续跟。
#
# 退出：Ctrl+C

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
BACKEND_LOG="$LOG_DIR/backend.log"
CLIENT_LOG="$LOG_DIR/client.log"

mode="${1:-all}"

title() { printf '\n== QuVideo 日志（模式：%s）==\n' "$1"; printf '   Ctrl+C 退出\n\n'; }
die()   { printf '  [错误] %s\n' "$*" >&2; exit 1; }

case "$mode" in
  backend)
    title "$mode"
    [ -f "$BACKEND_LOG" ] || die "找不到 $BACKEND_LOG，请先执行 scripts/dev-start.cmd"
    tail -n 200 -F "$BACKEND_LOG"
    ;;

  client)
    title "$mode"
    [ -f "$CLIENT_LOG" ] || die "找不到 $CLIENT_LOG，请先执行 scripts/dev-start.cmd"
    tail -n 200 -F "$CLIENT_LOG"
    ;;

  error)
    title "error（仅 ERROR / Exception）"
    [ -f "$BACKEND_LOG" ] || die "找不到 $BACKEND_LOG，请先执行 scripts/dev-start.cmd"
    tail -n 400 -F "$BACKEND_LOG" \
      | grep --line-buffered -E 'ERROR|Exception|Caused by'
    ;;

  warn)
    title "warn（ERROR + WARN）"
    [ -f "$BACKEND_LOG" ] || die "找不到 $BACKEND_LOG，请先执行 scripts/dev-start.cmd"
    tail -n 400 -F "$BACKEND_LOG" \
      | grep --line-buffered -E 'ERROR|WARN|Exception|Caused by'
    ;;

  all|*)
    title "all"
    if [ ! -f "$BACKEND_LOG" ] && [ ! -f "$CLIENT_LOG" ]; then
      die "两个日志都不存在，请先执行 scripts/dev-start.cmd"
    fi
    # tail 对多个文件会在切换时打印 ==> 文件名 <== 头，方便区分来源
    tail -n 60 -F "$BACKEND_LOG" "$CLIENT_LOG"
    ;;
esac

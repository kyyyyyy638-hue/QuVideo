#!/usr/bin/env bash
# QuVideo 关闭脚本
#
# 用法（三选一）：
#   1) 双击 scripts/dev-stop.cmd              ← Windows 下最省事
#   2) 在 Git Bash 窗口里：bash scripts/dev-stop.sh [--all]
#   3) PowerShell 里：
#        & "C:\Program Files\Git\bin\bash.exe" "E:\代码项目\DUOVIDEO\scripts\dev-stop.sh"
#
#   ⚠ 不要在 PowerShell/CMD 里直接敲 `bash ...`，那会命中 WSL 的 stub 而失败。
#
#   不加 --all ：只关后端 + 前端，保留中间件（数据服务继续跑）
#   加   --all ：连中间件容器一起停（不删数据卷）
#
# 为什么按「端口」而不是按 PID 关：
#   ./mvnw spring-boot:run 会派生出 Maven 进程 + 应用 JVM 两层，
#   只杀 wrapper 的 PID 往往留下应用 JVM 继续占着 9090。
#   按监听端口反查 PID 再杀，最可靠。

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BACKEND_PORT=9090
FRONTEND_PORT=15173
LOG_DIR="$ROOT_DIR/logs"

info()  { printf '  %s\n' "$*"; }
title() { printf '\n== %s ==\n' "$*"; }

stop_port() {
  local port="$1" name="$2"
  local pids
  pids="$(netstat -ano 2>/dev/null | awk -v p=":$port" '$4=="LISTENING" && $2 ~ p"$" {print $5}' | sort -u)"
  if [ -z "$pids" ]; then
    info "$name（端口 $port）本来就没在跑"
    return 0
  fi
  local pid
  for pid in $pids; do
    # //F 是为了绕开 MSYS 把 /F 当成路径的转换
    taskkill //F //PID "$pid" >/dev/null 2>&1 \
      && info "$name 已关闭（端口 $port，PID $pid）" \
      || info "$name 关闭失败（端口 $port，PID $pid），可手动执行：taskkill //F //PID $pid"
  done
}

title "关闭前端"
stop_port "$FRONTEND_PORT" "前端 Vite"

title "关闭后端"
stop_port "$BACKEND_PORT" "后端 Spring Boot"

rm -f "$LOG_DIR/backend.pid" "$LOG_DIR/client.pid" 2>/dev/null

if [ "${1:-}" = "--all" ]; then
  title "关闭中间件容器"
  if command -v docker >/dev/null 2>&1 || [ -x "/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]; then
    export PATH="/c/Program Files/Docker/Docker/resources/bin:$PATH"
    docker compose --env-file .env down 2>&1 | tail -8
    info "中间件已停（数据仍保留在 mysql/data、redis/data、minio/data、qdrant/data、rocketmq/{store,logs}）"
  else
    info "找不到 docker，跳过"
  fi
else
  title "完成"
  cat <<EOF
  后端与前端已关闭，中间件容器仍在运行。
  若要连中间件一起关：bash scripts/dev-stop.sh --all
  （该命令不会删除任何数据）
EOF
fi

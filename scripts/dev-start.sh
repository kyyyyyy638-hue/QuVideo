#!/usr/bin/env bash
# QuVideo 一键启动：中间件 → 后端 → 前端
#
# 用法（三选一）：
#   1) 双击 scripts/dev-start.cmd              ← Windows 下最省事，推荐
#   2) 在 Git Bash 窗口里：bash scripts/dev-start.sh
#   3) PowerShell 里：
#        & "C:\Program Files\Git\bin\bash.exe" "E:\代码项目\DUOVIDEO\scripts\dev-start.sh"
#
#   ⚠ 不要在 PowerShell/CMD 里直接敲 `bash scripts/dev-start.sh`。
#     `bash` 会解析到 C:\Windows\System32\bash.exe（WSL 的 stub），
#     本机未安装 WSL 发行版，会报 "execvpe(/bin/bash) failed"。
#
# 说明：
#   - 会自动补齐 PATH 与 JAVA_HOME，不依赖当前终端的环境（因此不会踩
#     「装完工具但 PATH 是旧的」和「JAVA_HOME 指向 JDK 26 导致编译失败」这两个坑）。
#   - 日志分别写入 logs/backend.log 与 logs/client.log。
#   - 关闭请用 scripts/dev-stop.sh。

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

BACKEND_PORT=9090
FRONTEND_PORT=15173

info()  { printf '  %s\n' "$*"; }
title() { printf '\n== %s ==\n' "$*"; }
die()   { printf '  [失败] %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. 补齐 PATH：Docker CLI + winget 装的 ffmpeg / tesseract
#    这些工具装好后需要新终端才进 PATH，而脚本可能在旧终端里被调用。
# ---------------------------------------------------------------------------
DOCKER_BIN="/c/Program Files/Docker/Docker/resources/bin"
TESS_BIN="/c/Program Files/Tesseract-OCR"
FFMPEG_BIN="$(ls -d /c/Users/*/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg*/ffmpeg-*/bin 2>/dev/null | head -1)"

EXTRA_PATH=""
for p in "$DOCKER_BIN" "$TESS_BIN" "$FFMPEG_BIN"; do
  [ -n "$p" ] && [ -d "$p" ] && EXTRA_PATH="$EXTRA_PATH:$p"
done
export PATH="${EXTRA_PATH#:}:$PATH"

# ---------------------------------------------------------------------------
# 2. 定位可用的 JDK（要求 21–25）
#    < 21 过不了 pom 的 enforcer；>= 26 会让 Spring Boot 3.5.9 锁定的
#    Lombok 1.18.42 崩掉（JDK 26 需要 Lombok >= 1.18.46）。
#    优先用 IDEA 自带的 JBR，避免额外安装。
# ---------------------------------------------------------------------------
detect_java_home() {
  shopt -s nullglob
  # 注意：glob 必须在「数组赋值」时就展开。若先存成字符串再用未加引号的
  # $var 去遍历，含空格的路径会被词分割拆断（IntelliJ IDEA 的目录名就带空格）。
  local candidates=(
    /d/APP/IntelliJ\ IDEA*/jbr
    /c/Program\ Files/JetBrains/*/jbr
    /c/Program\ Files/Eclipse\ Adoptium/jdk-2*
    /d/jdk-2*
  )
  local d v
  for d in "${candidates[@]}"; do
    [ -x "$d/bin/java.exe" ] || continue
    v="$(sed -n 's/^JAVA_VERSION="\([0-9]*\).*/\1/p' "$d/release" 2>/dev/null | head -1)"
    [ -n "$v" ] || continue
    if [ "$v" -ge 21 ] 2>/dev/null && [ "$v" -le 25 ] 2>/dev/null; then
      printf '%s' "$d"
      return 0
    fi
  done
  return 1
}

title "0/3 环境自检"

if ! JAVA_HOME="$(detect_java_home)"; then
  die "找不到 JDK 21-25。可用：winget install --id EclipseAdoptium.Temurin.21.JDK -e"
fi
export JAVA_HOME
info "JDK        : $JAVA_HOME ($("$JAVA_HOME/bin/java" -version 2>&1 | head -1))"

command -v docker   >/dev/null 2>&1 || die "找不到 docker，请确认 Docker Desktop 已安装"
command -v ffmpeg   >/dev/null 2>&1 || die "找不到 ffmpeg（后端关键帧抽取依赖它，必须在 PATH）"
command -v tesseract >/dev/null 2>&1 || die "找不到 tesseract（OCR 依赖它，必须在 PATH）"
info "ffmpeg     : $(command -v ffmpeg)"
info "tesseract  : $(command -v tesseract)"

docker info >/dev/null 2>&1 || die "Docker 引擎未运行。请先手动打开 Docker Desktop，等托盘图标变绿后重试。"

[ -f "$ROOT_DIR/.env" ] || die "缺少 .env（可执行 cp .env.example .env 后填写密钥）"

# ---------------------------------------------------------------------------
# 3. 中间件（6 个容器）
# ---------------------------------------------------------------------------
title "1/3 启动中间件"
if bash "$ROOT_DIR/scripts/dev-up.sh"; then
  info "中间件就绪"
else
  die "中间件启动失败，排查：docker compose --env-file .env ps 与 docker compose --env-file .env logs <服务名>"
fi

# ---------------------------------------------------------------------------
# 4. 后端
# ---------------------------------------------------------------------------
title "2/3 启动后端（端口 $BACKEND_PORT）"

if netstat -ano 2>/dev/null | awk -v p=":$BACKEND_PORT" '$4=="LISTENING" && $2 ~ p"$"' | grep -q .; then
  info "端口 $BACKEND_PORT 已被占用，跳过启动（若不需要可先执行 scripts/dev-stop.sh）"
else
  set -a; . "$ROOT_DIR/.env"; set +a
  ( cd "$ROOT_DIR/server" && nohup ./mvnw spring-boot:run > "$LOG_DIR/backend.log" 2>&1 & echo $! > "$LOG_DIR/backend.pid" )
  info "已在后台启动，日志：logs/backend.log"

  printf '  等待就绪'
  ready=0
  for _ in $(seq 1 40); do
    if curl -s --noproxy '*' --max-time 3 "http://127.0.0.1:$BACKEND_PORT/health" 2>/dev/null | grep -q '"UP"'; then
      ready=1; break
    fi
    printf '.'; sleep 3
  done
  printf '\n'
  [ "$ready" = "1" ] || die "后端 120 秒内未就绪，请看 logs/backend.log 末尾"
  info "后端就绪"
fi

curl -s --noproxy '*' --max-time 5 "http://127.0.0.1:$BACKEND_PORT/health" | head -c 120; printf '\n'

# ---------------------------------------------------------------------------
# 5. 前端
# ---------------------------------------------------------------------------
title "3/3 启动前端（端口 $FRONTEND_PORT）"

if netstat -ano 2>/dev/null | awk -v p=":$FRONTEND_PORT" '$4=="LISTENING" && $2 ~ p"$"' | grep -q .; then
  info "端口 $FRONTEND_PORT 已被占用，跳过启动"
else
  ( cd "$ROOT_DIR/client" && nohup npm run dev > "$LOG_DIR/client.log" 2>&1 & echo $! > "$LOG_DIR/client.pid" )
  info "已在后台启动，日志：logs/client.log"

  printf '  等待就绪'
  ready=0
  for _ in $(seq 1 20); do
    if curl -s --noproxy '*' --max-time 3 -o /dev/null "http://localhost:$FRONTEND_PORT/" 2>/dev/null; then
      ready=1; break
    fi
    printf '.'; sleep 2
  done
  printf '\n'
  [ "$ready" = "1" ] || die "前端 40 秒内未就绪，请看 logs/client.log"
  info "前端就绪"
fi

# ---------------------------------------------------------------------------
title "全部就绪"
cat <<EOF
  访问地址   http://localhost:$FRONTEND_PORT     ← 注意用 localhost，不要用 127.0.0.1
  后端直连   http://127.0.0.1:$BACKEND_PORT/health
  后端日志   logs/backend.log
  前端日志   logs/client.log
  关闭全部   bash scripts/dev-stop.sh
EOF

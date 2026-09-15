#!/usr/bin/env bash
# ==============================================================================
# NavHub 树莓派部署脚本
#
# 作用：把 WebNavHub 部署到树莓派，并用 systemd 常驻：
#   1. 克隆（或复用已有的）git 仓库到 /opt/WebNavHub
#   2. 定时 git pull，把网页上同步进仓库的改动自动拉下来
#   3. 用 python3 起静态服务监听 0.0.0.0:8080
#   4. 注册为 systemd 服务，开机自启、崩溃自重启
#
# 用法（在树莓派上执行）：
#   chmod +x tools/deploy-pi.sh
#   ./tools/deploy-pi.sh                      # 用公开仓库 HTTPS 拉取
#   ./tools/deploy-pi.sh --port 80            # 换个端口
#   ./tools/deploy-pi.sh --dir ~/WebNavHub    # 换个安装目录
#   ./tools/deploy-pi.sh --pull-interval 60   # 每 60 秒检查一次更新
#
# 说明：本脚本需要 sudo 权限来写 systemd 配置。
# ==============================================================================

set -euo pipefail

REPO_URL="${NAVHUB_REPO_URL:-https://github.com/Codivs-Ctrl/WebNavHub.git}"
BRANCH="${NAVHUB_BRANCH:-main}"
INSTALL_DIR="${NAVHUB_DIR:-/opt/WebNavHub}"
PORT=8080
PULL_INTERVAL=300
SERVICE_NAME="navhub"
SKIP_SERVICE=0

log()  { printf '\033[0;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m✅ %s\033[0m\n' "$*"; }
warn() { printf '\033[0;33m⚠️  %s\033[0m\n' "$*"; }
die()  { printf '\033[0;31m❌ %s\033[0m\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --port)          PORT="${2:-8080}"; shift ;;
        --dir)           INSTALL_DIR="${2:-}"; shift ;;
        --repo)          REPO_URL="${2:-}"; shift ;;
        --branch)        BRANCH="${2:-main}"; shift ;;
        --pull-interval) PULL_INTERVAL="${2:-300}"; shift ;;
        --no-service)    SKIP_SERVICE=1 ;;
        -h|--help)       sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "未知参数：$1" ;;
    esac
    shift
done

# ------------------------------------------------------------------------------
# 0. 环境检查
# ------------------------------------------------------------------------------
log "检查运行环境"
for cmd in git python3; do
    command -v "$cmd" >/dev/null 2>&1 || die "缺少命令：$cmd（执行 sudo apt update && sudo apt install -y git python3）"
done
ok "git 与 python3 均可用：$(python3 --version 2>&1)"

# 端口占用提醒
if command -v ss >/dev/null 2>&1 && ss -lnt 2>/dev/null | grep -q ":${PORT} "; then
    die "端口 ${PORT} 已被占用，换一个：--port 8080"
fi

# ------------------------------------------------------------------------------
# 1. 准备代码目录
# ------------------------------------------------------------------------------
log "准备代码目录：$INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
    ok "目录已存在且是 git 仓库，执行更新"
    git -C "$INSTALL_DIR" fetch origin "$BRANCH"
    git -C "$INSTALL_DIR" checkout "$BRANCH"
    if ! git -C "$INSTALL_DIR" pull --rebase --autostash origin "$BRANCH"; then
        warn "自动更新失败，请手动到 $INSTALL_DIR 处理冲突后再重试"
    fi
else
    if [ -e "$INSTALL_DIR" ]; then
        die "目录已存在但不是 git 仓库：$INSTALL_DIR（请先备份移走，或用 --dir 换个路径）"
    fi
    sudo mkdir -p "$(dirname "$INSTALL_DIR")"
    sudo chown "$(id -u):$(id -g)" "$(dirname "$INSTALL_DIR")"
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
    ok "已克隆仓库"
fi

[ -f "$INSTALL_DIR/index.html" ] || die "未找到 $INSTALL_DIR/index.html，仓库内容可能不完整"

# 让脚本可执行
chmod +x "$INSTALL_DIR/tools/"*.sh 2>/dev/null || true

# ------------------------------------------------------------------------------
# 2. 校验数据文件
# ------------------------------------------------------------------------------
# 注意：这里不再调用 sync-local.sh。git pull 拿到的 data/sites.js 才是权威版本，
# 而 raw.githubusercontent.com 有数分钟 CDN 缓存，反而可能把文件覆盖成旧内容。
if [ -s "$INSTALL_DIR/data/sites.js" ]; then
    ok "data/sites.js 已就绪（$(grep -c '"name"' "$INSTALL_DIR/data/sites.js" 2>/dev/null || echo '?') 个站点条目）"
else
    warn "未找到或数据文件为空：$INSTALL_DIR/data/sites.js"
fi

# ------------------------------------------------------------------------------
# 3. 写入 systemd 服务
# ------------------------------------------------------------------------------
start_now() {
    sudo systemctl daemon-reload
    sudo systemctl enable --now "$SERVICE_NAME.service" >/dev/null
}

stop_old() {
    if systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}.service"; then
        sudo systemctl stop "$SERVICE_NAME.service" 2>/dev/null || true
    fi
}

if [ "$SKIP_SERVICE" -eq 1 ]; then
    warn "已跳过 systemd 配置，可手动启动："
    echo "   cd $INSTALL_DIR && python3 -m http.server $PORT --bind 0.0.0.0"
    exit 0
fi

log "配置 systemd 服务（需要 sudo）"

# 3.1 静态服务
sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=NavHub 导航主页静态服务
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(id -un)
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/env python3 -m http.server $PORT --bind 0.0.0.0
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 3.2 定时拉取（用 systemd timer，比 cron 更好管理日志）
sudo tee "/etc/systemd/system/${SERVICE_NAME}-pull.service" >/dev/null <<EOF
[Unit]
Description=NavHub 拉取仓库最新数据
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$(id -un)
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/env git pull --rebase --autostash origin $BRANCH
EOF

sudo tee "/etc/systemd/system/${SERVICE_NAME}-pull.timer" >/dev/null <<EOF
[Unit]
Description=定时拉取 NavHub 更新（每 ${PULL_INTERVAL} 秒）
Requires=${SERVICE_NAME}-pull.service

[Timer]
OnBootSec=30
OnUnitActiveSec=${PULL_INTERVAL}
AccuracySec=10
Unit=${SERVICE_NAME}-pull.service

[Install]
WantedBy=timers.target
EOF

stop_old
start_now
sudo systemctl enable --now "${SERVICE_NAME}-pull.timer" >/dev/null

# ------------------------------------------------------------------------------
# 4. 结果
# ------------------------------------------------------------------------------
sleep 2

IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -n "$IP_ADDR" ] || IP_ADDR="<树莓派IP>"

echo
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
    ok "部署完成！"
else
    warn "服务未处于运行状态，查看日志排查：sudo journalctl -u ${SERVICE_NAME} -n 50"
fi

cat <<EOF

  访问地址   http://${IP_ADDR}:${PORT}/
  访问目录   ${INSTALL_DIR}
  自动更新   每 ${PULL_INTERVAL} 秒 git pull 一次（systemd timer）

常用命令：
  sudo systemctl status  ${SERVICE_NAME}
  sudo systemctl restart ${SERVICE_NAME}
  sudo journalctl -u ${SERVICE_NAME} -f
  systemctl list-timers ${SERVICE_NAME}-pull.timer

如需开机自动配置无线网络或固定 IP，可用 sudo raspi-config。
若 80 端口要用，需 sudo 权限：把服务的 User 改为 root，或给 python3 授权
（sudo setcap 'cap_net_bind_service=+ep' \$(readlink -f \$(command -v python3))）。
EOF

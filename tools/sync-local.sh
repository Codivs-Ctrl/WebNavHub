#!/usr/bin/env bash
# ==============================================================================
# NavHub 本机数据文件同步脚本（Linux / macOS / 树莓派 版）
#
# 与仓库内 tools/sync-local.ps1（Windows 版）功能一致：
#   · 默认：从 GitHub 拉取 data/sites.js 到本机，内容不同才覆盖，旧文件备份为 .bak
#   · -w / --watch   ：循环监听，云端有更新就写回本机
#   · -p / --push    ：本机文件有改动时，git 提交并推送到仓库
#
# 用法：
#   ./tools/sync-local.sh                 # 拉取一次
#   ./tools/sync-local.sh --watch         # 每 30 秒检查一次（Ctrl+C 退出）
#   ./tools/sync-local.sh --watch -i 10   # 自定义间隔（秒）
#   ./tools/sync-local.sh --push          # 本机 → 云端
#   NAVHUB_TOKEN=github_pat_xxx ./tools/sync-local.sh   # 私有仓库带令牌
#
# 建议配合 cron 使用（每 5 分钟拉一次）：
#   */5 * * * * cd /home/pi/WebNavHub && ./tools/sync-local.sh >> /tmp/navhub-sync.log 2>&1
# ==============================================================================

set -uo pipefail

REPO="${NAVHUB_REPO:-Codivs-Ctrl/WebNavHub}"
BRANCH="${NAVHUB_BRANCH:-main}"
FILE_PATH="${NAVHUB_PATH:-data/sites.js}"

# 脚本位于 <repo>/tools/ 下，默认操作仓库根目录的 data/sites.js
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_FILE="${NAVHUB_LOCAL_FILE:-$(dirname "$SCRIPT_DIR")/data/sites.js}"

INTERVAL=30
WATCH=0
PUSH=0
FORCE=0

log() {
    local color="$1"; shift
    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    if [ -t 1 ]; then
        printf '\033[%sm[%s] %s\033[0m\n' "$color" "$ts" "$*"
    else
        printf '[%s] %s\n' "$ts" "$*"
    fi
}
info()  { log '0;37' "$@"; }
ok()    { log '0;32' "$@"; }
warn()  { log '0;33' "$@"; }
err()   { log '0;31' "$@" >&2; }

usage() {
    sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -w|--watch)  WATCH=1 ;;
        -p|--push)   PUSH=1 ;;
        -f|--force)  FORCE=1 ;;
        -i|--interval) INTERVAL="${2:-30}"; shift ;;
        --local-file)  LOCAL_FILE="${2:-}"; shift ;;
        -h|--help)   usage ;;
        *) err "未知参数：$1（用 -h 查看帮助）"; exit 1 ;;
    esac
    shift
done

# 依赖检查
for cmd in curl; do
    command -v "$cmd" >/dev/null 2>&1 || { err "缺少命令：$cmd（Debian/Ubuntu 可执行 sudo apt install -y curl）"; exit 1; }
done

# ------------------------------------------------------------------------------
# 拉取：云端 → 本机
# ------------------------------------------------------------------------------
fetch_remote() {
    local url="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${FILE_PATH}"
    local -a headers=(-H 'User-Agent: NavHub-Sync' -H 'Cache-Control: no-cache')
    if [ -n "${NAVHUB_TOKEN:-}" ]; then
        headers+=(-H "Authorization: Bearer ${NAVHUB_TOKEN}")
    fi

    curl -fsSL --max-time 30 "${headers[@]}" "$url"
}

pull_once() {
    local remote tmp local_content
    tmp="$(mktemp)"

    if ! remote="$(fetch_remote 2>/dev/null)"; then
        rm -f "$tmp"
        err "拉取失败：${REPO}/${BRANCH}/${FILE_PATH}（检查网络、仓库名或令牌）"
        return 1
    fi

    if [ -z "$remote" ]; then
        rm -f "$tmp"
        err "拉取到的内容为空，已放弃写入"
        return 1
    fi

    # 保留文件末尾换行，与页面里的写入结果保持一致
    printf '%s\n' "$remote" > "$tmp"

    local_content=""
    if [ -f "$LOCAL_FILE" ]; then
        local_content="$(cat "$LOCAL_FILE")"
    else
        warn "本机文件不存在，将新建：$LOCAL_FILE"
    fi

    if [ "$local_content" = "$remote" ]; then
        rm -f "$tmp"
        info "云端与本机一致，无需更新。"
        return 2   # 2 = 无变化
    fi

    # 备份旧文件，便于回滚
    if [ -f "$LOCAL_FILE" ] && [ "$FORCE" -eq 0 ]; then
        cp -f "$LOCAL_FILE" "${LOCAL_FILE}.bak"
        info "已备份本机旧文件 → ${LOCAL_FILE}.bak"
    fi

    mkdir -p "$(dirname "$LOCAL_FILE")"
    # 先写临时文件再原子替换，避免服务读取到半截内容
    mv -f "$tmp" "$LOCAL_FILE"
    ok "✅ 已从云端更新 $FILE_PATH"
    return 0
}

# ------------------------------------------------------------------------------
# 推送：本机 → 云端
# ------------------------------------------------------------------------------
push_once() {
    if [ ! -f "$LOCAL_FILE" ]; then
        err "本机文件不存在：$LOCAL_FILE"
        return 1
    fi

    command -v git >/dev/null 2>&1 || { err "缺少命令：git"; return 1; }

    local repo_root; repo_root="$(dirname "$SCRIPT_DIR")"
    cd "$repo_root" || return 1

    if [ ! -d .git ]; then
        err "$repo_root 不是 git 仓库，无法推送（可改用页面云同步）"
        return 1
    fi

    local rel_path; rel_path="$(realpath --relative-to="$repo_root" "$LOCAL_FILE" 2>/dev/null || echo "$FILE_PATH")"

    if [ -z "$(git status --porcelain -- "$rel_path")" ]; then
        info "本机文件没有未提交的改动。"
        return 2
    fi

    git add -- "$rel_path" || return 1
    git commit -m "chore(nav): 本机更新站点数据（$(date '+%Y-%m-%d %H:%M:%S')）" >/dev/null || return 1

    if git push origin "$BRANCH" >/dev/null 2>&1; then
        ok "✅ 已提交并推送到仓库。"
    else
        err "推送失败：请检查远端权限（SSH key 或令牌）"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 主流程
# ------------------------------------------------------------------------------
if [ "$PUSH" -eq 1 ]; then
    push_once
    exit $?
fi

if [ "$WATCH" -eq 1 ]; then
    info "监听中：每 ${INTERVAL} 秒检查一次 ${REPO}/${BRANCH}/${FILE_PATH}（Ctrl+C 退出）"
    while true; do
        pull_once || true
        sleep "$INTERVAL"
    done
fi

pull_once

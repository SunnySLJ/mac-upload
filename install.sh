#!/bin/bash
# ============================================================
# mac-openclaw 一键部署脚本
# 功能: 自动部署/更新 OpenClaw + xiaolong-upload + openclaw_upload
# 支持: 全新安装 + 智能更新
# Python: 统一使用 Python 3.12
# ============================================================

set -euo pipefail

# ── 颜色定义 ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── 全局变量 ─────────────────────────────────────────────────
OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$OPENCLAW_DIR/workspace"
SKILLS_DIR="$OPENCLAW_DIR/skills"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PYTHON_CMD=""
OPENCLAW_VERSION="2026.3.28"
IS_UPDATE_MODE=false

# ── 工具函数 ─────────────────────────────────────────────────
ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; }
info() { echo -e "  ${CYAN}ℹ️  $1${NC}"; }

check_command() { command -v "$1" &>/dev/null; }

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local answer
    if [ "$default" = "y" ]; then
        read -rp "  $prompt [Y/n]: " answer
        answer="${answer:-y}"
    else
        read -rp "  $prompt [y/N]: " answer
        answer="${answer:-n}"
    fi
    [[ "$answer" =~ ^[Yy] ]]
}

# ── 检测是否已安装 ──────────────────────────────────────────
detect_installation() {
    echo ""
    echo -e "${BOLD}🔍 检测安装状态...${NC}"

    local openclaw_installed=false
    local xiaolong_installed=false
    local openclaw_upload_installed=false

    # 检测 OpenClaw
    if check_command openclaw; then
        openclaw_installed=true
        info "OpenClaw: 已安装 ($(openclaw --version 2>/dev/null || echo '未知版本'))"
    else
        info "OpenClaw: 未安装"
    fi

    # 检测 xiaolong-upload
    if [ -d "$WORKSPACE_DIR/xiaolong-upload" ]; then
        xiaolong_installed=true
        info "xiaolong-upload: 已安装 ($WORKSPACE_DIR/xiaolong-upload)"
    else
        info "xiaolong-upload: 未安装"
    fi

    # 检测 openclaw_upload
    if [ -d "$WORKSPACE_DIR/openclaw_upload" ]; then
        openclaw_upload_installed=true
        info "openclaw_upload: 已安装 ($WORKSPACE_DIR/openclaw_upload)"
    else
        info "openclaw_upload: 未安装"
    fi

    # 判断模式
    if $openclaw_installed && $xiaolong_installed && $openclaw_upload_installed; then
        IS_UPDATE_MODE=true
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}检测到完整安装，进入【更新模式】${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 0
    elif $openclaw_installed; then
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}OpenClaw 已安装，将补充安装项目${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 1
    else
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}全新安装模式${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 2
    fi
}

# ── 步骤 1: 系统环境检查 ─────────────────────────────────────
step_system_check() {
    echo ""
    echo -e "${BOLD}[1/7] 系统环境检查${NC}"

    if [[ "$(uname)" != "Darwin" ]]; then
        fail "此脚本仅支持 macOS"
        exit 1
    fi
    ok "macOS $(sw_vers -productVersion)"

    if check_command node; then
        ok "Node.js: $(node -v)"
    else
        fail "未安装 Node.js"
        info "安装: brew install node"
        exit 1
    fi

    if check_command git; then
        ok "Git: $(git --version | awk '{print $3}')"
    else
        fail "未安装 Git"
        info "安装: brew install git"
        exit 1
    fi
}

# ── 步骤 2: Python 3.12 安装与配置 ───────────────────────────
step_python() {
    echo ""
    echo -e "${BOLD}[2/7] Python 3.12 安装与配置${NC}"

    # 检查 Homebrew
    if ! check_command brew; then
        fail "未安装 Homebrew"
        info "安装: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    ok "Homebrew: 已安装"

    # 检查 Python 3.12
    local python_candidates=(
        "/opt/homebrew/bin/python3.12"
        "/usr/local/bin/python3.12"
    )

    for cmd in "${python_candidates[@]}"; do
        if [ -x "$cmd" ]; then
            PYTHON_CMD="$cmd"
            break
        fi
    done

    # 如果没找到，安装 Python 3.12
    if [ -z "$PYTHON_CMD" ]; then
        info "正在安装 Python 3.12..."
        brew install python@3.12
        PYTHON_CMD="/opt/homebrew/bin/python3.12"
    fi

    ok "Python 3.12: $PYTHON_CMD ($($PYTHON_CMD --version))"

    # 配置 Python 3.12 为默认 Python（添加到 PATH）
    local brew_prefix="/opt/homebrew"
    local python_bin="$brew_prefix/opt/python@3.12/libexec/bin"

    # 检查是否已配置
    if ! echo "$PATH" | grep -q "python@3.12/libexec"; then
        info "配置 Python 3.12 为默认版本..."

        # 添加到 shell 配置文件
        for rc_file in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile"; do
            if [ -f "$rc_file" ] || [[ "$rc_file" == *".zprofile"* ]] || [[ "$rc_file" == *".zshrc"* ]]; then
                if ! grep -q "python@3.12/libexec" "$rc_file" 2>/dev/null; then
                    echo "" >> "$rc_file"
                    echo "# Python 3.12 as default" >> "$rc_file"
                    echo "export PATH=\"$python_bin:\$PATH\"" >> "$rc_file"
                    echo "alias python='python3.12'" >> "$rc_file"
                    echo "alias pip='pip3.12'" >> "$rc_file"
                fi
            fi
        done

        # 立即生效
        export PATH="$python_bin:$PATH"

        ok "已添加 Python 3.12 到 PATH"
    else
        ok "Python 3.12 已在 PATH 中"
    fi

    # 验证 python 命令指向 3.12
    if check_command python3.12; then
        ok "python3.12 命令可用"
    fi
}

# ── 步骤 3: 安装/更新 OpenClaw ───────────────────────────────
step_openclaw() {
    echo ""
    echo -e "${BOLD}[3/7] OpenClaw${NC}"

    if check_command openclaw; then
        local current_ver
        current_ver=$(openclaw --version 2>/dev/null || echo "unknown")
        ok "当前版本: $current_ver"

        if ask_yes_no "是否更新到 $OPENCLAW_VERSION？"; then
            npm install -g "openclaw@$OPENCLAW_VERSION"
            ok "已更新到 $OPENCLAW_VERSION"
        else
            info "保持当前版本"
        fi
    else
        info "安装 OpenClaw $OPENCLAW_VERSION..."
        npm install -g "openclaw@$OPENCLAW_VERSION"
        ok "OpenClaw $OPENCLAW_VERSION 已安装"
    fi

    mkdir -p "$OPENCLAW_DIR" "$WORKSPACE_DIR" "$SKILLS_DIR"
    mkdir -p "$WORKSPACE_DIR/inbound_images" "$WORKSPACE_DIR/logs/auth_qr"
}

# ── 步骤 4: 安装/更新 xiaolong-upload ─────────────────────────
step_xiaolong_upload() {
    echo ""
    echo -e "${BOLD}[4/7] xiaolong-upload (视频号上传)${NC}"

    local target="$WORKSPACE_DIR/xiaolong-upload"

    if [ -d "$target" ]; then
        ok "已存在于 $target"
        if [ -d "$target/.git" ]; then
            if ask_yes_no "是否拉取最新代码？"; then
                cd "$target"
                git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || warn "git pull 失败"
                cd "$PROJECT_ROOT"
                ok "代码已更新"
            fi
        else
            warn "非 git 仓库，无法自动更新"
        fi
    else
        info "从本地项目复制..."
        if [ -d "$PROJECT_ROOT/xiaolong-upload" ]; then
            cp -R "$PROJECT_ROOT/xiaolong-upload" "$target"
            ok "已复制到 $target"
        else
            fail "找不到 xiaolong-upload 目录"
            exit 1
        fi
    fi

    # 安装 Python 依赖（使用 Python 3.12）
    if [ -f "$target/requirements.txt" ]; then
        info "安装 Python 依赖..."
        cd "$target"
        if [ ! -d ".venv" ]; then
            $PYTHON_CMD -m venv .venv
        fi
        .venv/bin/pip install -r requirements.txt -q
        ok "Python 依赖已安装"
        cd "$PROJECT_ROOT"
    fi
}

# ── 步骤 5: 安装/更新 openclaw_upload ─────────────────────────
step_openclaw_upload() {
    echo ""
    echo -e "${BOLD}[5/7] openclaw_upload (帧龙虾图生视频)${NC}"

    local target="$WORKSPACE_DIR/openclaw_upload"

    if [ -d "$target" ]; then
        ok "已存在于 $target"
        if [ -d "$target/.git" ]; then
            if ask_yes_no "是否拉取最新代码？"; then
                cd "$target"
                git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || warn "git pull 失败"
                cd "$PROJECT_ROOT"
                ok "代码已更新"
            fi
        else
            warn "非 git 仓库，无法自动更新"
        fi
    else
        info "从本地项目复制..."
        if [ -d "$PROJECT_ROOT/openclaw_upload" ]; then
            cp -R "$PROJECT_ROOT/openclaw_upload" "$target"
            ok "已复制到 $target"
        else
            fail "找不到 openclaw_upload 目录"
            exit 1
        fi
    fi

    # 安装 Python 依赖
    if [ -f "$target/requirements.txt" ]; then
        info "安装 Python 依赖..."
        cd "$target"
        if [ ! -d ".venv" ]; then
            $PYTHON_CMD -m venv .venv
        fi
        .venv/bin/pip install -r requirements.txt -q
        ok "Python 依赖已安装"
        cd "$PROJECT_ROOT"
    fi

    # 创建 output 目录
    mkdir -p "$target/flash_longxia/output"
}

# ── 步骤 6: 同步 Skills ───────────────────────────────────────
step_skills() {
    echo ""
    echo -e "${BOLD}[6/7] Skills 同步${NC}"

    mkdir -p "$SKILLS_DIR"

    # 从 xiaolong-upload 同步
    local xiaolong_skills="$WORKSPACE_DIR/xiaolong-upload/skills"
    if [ -d "$xiaolong_skills" ]; then
        for skill in auth longxia-upload video-cleanup login-monitor; do
            if [ -d "$xiaolong_skills/$skill" ]; then
                cp -R "$xiaolong_skills/$skill" "$SKILLS_DIR/$skill" 2>/dev/null || true
                ok "Skill [$skill] 已同步"
            fi
        done
    fi

    # 从 openclaw_upload 同步
    local openclaw_skills="$WORKSPACE_DIR/openclaw_upload/skills"
    if [ -d "$openclaw_skills" ]; then
        for skill in flash-longxia; do
            if [ -d "$openclaw_skills/$skill" ]; then
                cp -R "$openclaw_skills/$skill" "$SKILLS_DIR/$skill" 2>/dev/null || true
                ok "Skill [$skill] 已同步"
            fi
        done
    fi

    # 从 deploy/skills 同步
    if [ -d "$PROJECT_ROOT/deploy/skills" ]; then
        for skill in longxia-bootstrap repo-sync; do
            if [ -d "$PROJECT_ROOT/deploy/skills/$skill" ]; then
                cp -R "$PROJECT_ROOT/deploy/skills/$skill" "$SKILLS_DIR/$skill" 2>/dev/null || true
                ok "Skill [$skill] 已同步"
            fi
        done
    fi
}

# ── 步骤 7: 同步 Workspace 配置 ───────────────────────────────
sync_workspace_config() {
    echo ""
    echo -e "${BOLD}[7/7] Workspace 配置${NC}"

    local ws_src="$PROJECT_ROOT/deploy/workspace"

    if [ -d "$ws_src" ]; then
        for f in AGENTS.md IDENTITY.md SOUL.md USER.md MEMORY.md HEARTBEAT.md TOOLS.md; do
            if [ -f "$ws_src/$f" ] && [ ! -f "$WORKSPACE_DIR/$f" ]; then
                cp "$ws_src/$f" "$WORKSPACE_DIR/$f"
                ok "$f 已复制"
            elif [ -f "$ws_src/$f" ] && [ -f "$WORKSPACE_DIR/$f" ]; then
                warn "$f 已存在，跳过"
            fi
        done
    fi
}

# ── 创建更新脚本 ─────────────────────────────────────────────
create_update_script() {
    cat > "$WORKSPACE_DIR/update-all.sh" << 'UPDATE_EOF'
#!/bin/bash
# 一键更新所有项目
set -e

echo "🔄 更新所有项目..."

WORKSPACE="$HOME/.openclaw/workspace"
PYTHON_CMD="/opt/homebrew/bin/python3.12"

# 更新 xiaolong-upload
if [ -d "$WORKSPACE/xiaolong-upload/.git" ]; then
    echo "📦 xiaolong-upload..."
    cd "$WORKSPACE/xiaolong-upload"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "  ⚠️ 更新失败"
    if [ -d ".venv" ]; then
        .venv/bin/pip install -r requirements.txt -q
    fi
fi

# 更新 openclaw_upload
if [ -d "$WORKSPACE/openclaw_upload/.git" ]; then
    echo "📦 openclaw_upload..."
    cd "$WORKSPACE/openclaw_upload"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "  ⚠️ 更新失败"
    if [ -d ".venv" ]; then
        .venv/bin/pip install -r requirements.txt -q
    fi
fi

# 同步 Skills
echo "📋 Skills 同步..."
SKILLS_DIR="$HOME/.openclaw/skills"
for skill in auth longxia-upload video-cleanup login-monitor; do
    if [ -d "$WORKSPACE/xiaolong-upload/skills/$skill" ]; then
        cp -R "$WORKSPACE/xiaolong-upload/skills/$skill" "$SKILLS_DIR/$skill" 2>/dev/null || true
        echo "  ✅ $skill"
    fi
done
for skill in flash-longxia; do
    if [ -d "$WORKSPACE/openclaw_upload/skills/$skill" ]; then
        cp -R "$WORKSPACE/openclaw_upload/skills/$skill" "$SKILLS_DIR/$skill" 2>/dev/null || true
        echo "  ✅ $skill"
    fi
done

echo "✅ 更新完成！"
UPDATE_EOF
    chmod +x "$WORKSPACE_DIR/update-all.sh"
    ok "update-all.sh 已创建"
}

# ── 最终验证 ─────────────────────────────────────────────────
verify() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}验证安装结果${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local all_ok=true

    # 检查 OpenClaw
    if check_command openclaw; then
        ok "OpenClaw: $(openclaw --version 2>/dev/null || echo '已安装')"
    else
        fail "OpenClaw: 未安装"
        all_ok=false
    fi

    # 检查 Python 3.12
    if [ -x "$PYTHON_CMD" ]; then
        ok "Python 3.12: $($PYTHON_CMD --version)"
    else
        fail "Python 3.12: 未安装"
        all_ok=false
    fi

    # 检查项目目录
    if [ -d "$WORKSPACE_DIR/xiaolong-upload" ]; then
        ok "xiaolong-upload: ✓"
    else
        fail "xiaolong-upload: 缺失"
        all_ok=false
    fi

    if [ -d "$WORKSPACE_DIR/openclaw_upload" ]; then
        ok "openclaw_upload: ✓"
    else
        fail "openclaw_upload: 缺失"
        all_ok=false
    fi

    # 检查 Skills
    local skill_count=0
    for skill in auth flash-longxia longxia-upload longxia-bootstrap video-cleanup; do
        if [ -d "$SKILLS_DIR/$skill" ]; then
            skill_count=$((skill_count + 1))
        fi
    done
    ok "Skills: $skill_count 个已安装"

    echo ""
    if $all_ok; then
        echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}  ${BOLD}🎉 安装/更新完成！${NC}                              ${GREEN}║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}  ${BOLD}⚠️  有部分问题，请检查${NC}                           ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
    fi

    echo ""
    echo -e "${BOLD}📋 后续操作：${NC}"
    echo "  1. 重启终端使 Python 3.12 配置生效"
    echo "  2. 启动 OpenClaw:    openclaw"
    echo "  3. 绑定微信:         openclaw channel connect openclaw-weixin"
    echo "  4. 更新代码:         ~/.openclaw/workspace/update-all.sh"
    echo ""
    echo -e "${CYAN}  工作区: $WORKSPACE_DIR${NC}"
    echo -e "${CYAN}  Python: $PYTHON_CMD${NC}"
}

# ── 主函数 ────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}🦐 mac-openclaw 一键部署脚本${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  OpenClaw + 视频号上传 + 图生视频${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  统一 Python 3.12${NC}                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

    # 检测安装状态
    detect_installation

    # 根据模式执行
    step_system_check
    step_python
    step_openclaw
    step_xiaolong_upload
    step_openclaw_upload
    step_skills
    sync_workspace_config
    create_update_script
    verify
}

main "$@"
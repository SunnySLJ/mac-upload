#!/bin/bash
# ============================================================
# mac-upload 一键部署脚本
# 功能: 自动部署/更新 OpenClaw + 图生视频 + 视频号发布
# 特性:
#   - 自动识别全新安装 vs 增量更新
#   - 用户个性化（AI 身份、行业、视频风格）
#   - Skills 同步（auth、flash-longxia、longxia-upload、video-cleanup）
#   - 定时任务：每周视频清理（无每日登录检查）
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
DEPLOY_DIR="$PROJECT_ROOT/deploy"
PYTHON_CMD=""
OPENCLAW_VERSION="2026.3.28"
IS_UPDATE_MODE=false

# ── 用户个性化默认值 ─────────────────────────────────────────
USER_DISPLAY_NAME=""
USER_INDUSTRY=""
USER_VIDEO_STYLE=""
AI_NAME="虾王"
AI_EMOJI="🦐"
AI_VIBE="轻松、幽默、直接，不啰嗦"
CONFIRM_BEFORE_PUBLISH="true"
API_KEY=""
LLM_PROVIDER="n1n.ai"
FEISHU_ENABLED=false
FEISHU_APP_ID=""
FEISHU_APP_SECRET=""
WECHAT_TARGET=""

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

ask_input() {
    local prompt="$1"
    local var_ref="$2"
    local default="$3"
    read -rp "  $prompt [$default]: " input_val
    input_val="${input_val:-$default}"
    printf -v "$var_ref" "%s" "$input_val"
}

# ── 检测安装模式 ─────────────────────────────────────────────
detect_mode() {
    echo ""
    echo -e "${BOLD}🔍 检测安装状态...${NC}"

    local openclaw_inst=false xiaolong_inst=false openclaw_upload_inst=false

    if check_command openclaw; then
        openclaw_inst=true
        info "OpenClaw: 已安装 ($(openclaw --version 2>/dev/null || echo '未知版本'))"
    else
        info "OpenClaw: 未安装"
    fi

    if [ -d "$WORKSPACE_DIR/xiaolong-upload" ]; then
        xiaolong_inst=true
        info "xiaolong-upload: 已安装"
    else
        info "xiaolong-upload: 未安装"
    fi

    if [ -d "$WORKSPACE_DIR/openclaw_upload" ]; then
        openclaw_upload_inst=true
        info "openclaw_upload: 已安装"
    else
        info "openclaw_upload: 未安装"
    fi

    if $openclaw_inst && $xiaolong_inst && $openclaw_upload_inst; then
        IS_UPDATE_MODE=true
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}检测到完整安装，进入【更新模式】${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    elif $openclaw_inst; then
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}OpenClaw 已安装，将补充安装缺失项目${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}全新安装模式${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

# ── 步骤 1: 系统环境检查 ─────────────────────────────────────
step_system() {
    echo ""
    echo -e "${BOLD}[1/8] 系统环境检查${NC}"

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

    if check_command brew; then
        ok "Homebrew: 已安装"
    fi
}

# ── 步骤 2: Python 3.12 ─────────────────────────────────────
step_python() {
    echo ""
    echo -e "${BOLD}[2/8] Python 3.12${NC}"

    local candidates=(
        "/opt/homebrew/bin/python3.12"
        "/usr/local/bin/python3.12"
        "python3.12"
    )

    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            local ver
            ver=$("$cmd" --version 2>&1 | awk '{print $2}')
            if [[ "$ver" == 3.12* ]]; then
                PYTHON_CMD="$cmd"
                ok "Python 3.12: $PYTHON_CMD ($ver)"
                return
            fi
        fi
    done

    if check_command brew; then
        if ask_yes_no "未找到 Python 3.12，是否使用 Homebrew 安装？"; then
            brew install python@3.12
            PYTHON_CMD="/opt/homebrew/bin/python3.12"
            ok "Python 3.12 已安装: $PYTHON_CMD"
        else
            fail "Python 3.12 是必需的"
            exit 1
        fi
    else
        fail "未找到 Python 3.12"
        info "安装: brew install python@3.12"
        exit 1
    fi
}

# ── 步骤 3: OpenClaw ────────────────────────────────────────
step_openclaw() {
    echo ""
    echo -e "${BOLD}[3/8] OpenClaw${NC}"

    if check_command openclaw; then
        local cur_ver
        cur_ver=$(openclaw --version 2>/dev/null || echo "unknown")
        ok "当前版本: $cur_ver"

        if [[ "$cur_ver" != "$OPENCLAW_VERSION" ]]; then
            if ask_yes_no "是否更新到 $OPENCLAW_VERSION？"; then
                npm install -g "openclaw@$OPENCLAW_VERSION"
                ok "已更新到 $OPENCLAW_VERSION"
            fi
        fi
    else
        info "安装 OpenClaw $OPENCLAW_VERSION..."
        npm install -g "openclaw@$OPENCLAW_VERSION"
        ok "OpenClaw $OPENCLAW_VERSION 已安装"
    fi

    mkdir -p "$OPENCLAW_DIR" "$WORKSPACE_DIR" "$SKILLS_DIR"
    mkdir -p "$WORKSPACE_DIR/inbound_images" "$WORKSPACE_DIR/logs/auth_qr"
    mkdir -p "$OPENCLAW_DIR/cron" "$OPENCLAW_DIR/credentials"
    ok "目录结构已创建"
}

# ── 步骤 4: 微信插件 ────────────────────────────────────────
step_wechat() {
    echo ""
    echo -e "${BOLD}[4/9] 微信插件${NC}"

    if [ -d "$HOME/.openclaw/extensions/openclaw-weixin" ]; then
        ok "微信插件已安装"
    else
        info "安装微信插件..."
        npx -y @tencent-weixin/openclaw-weixin-cli@latest install
        ok "微信插件安装完成"
    fi
    warn "启动后请运行: openclaw channel connect openclaw-weixin"
}

# ── 步骤 5: 飞书插件 ────────────────────────────────────────
step_feishu() {
    echo ""
    echo -e "${BOLD}[5/9] 飞书插件（可选）${NC}"

    if ask_yes_no "是否安装飞书插件？" "n"; then
        FEISHU_ENABLED=true
        info "请参考: https://docs.openclaw.ai/plugins/feishu"
        read -rp "  请输入飞书 App ID: " FEISHU_APP_ID
        FEISHU_APP_ID="${FEISHU_APP_ID:-}"
        if [ -n "$FEISHU_APP_ID" ]; then
            read -rp "  请输入飞书 App Secret: " FEISHU_APP_SECRET
            FEISHU_APP_SECRET="${FEISHU_APP_SECRET:-}"

            mkdir -p "$OPENCLAW_DIR/credentials"
            cat > "$OPENCLAW_DIR/credentials/feishu-main-allowFrom.json" << FEISHU_EOF
{
  "appId": "$FEISHU_APP_ID",
  "appSecret": "$FEISHU_APP_SECRET"
}
FEISHU_EOF
            ok "飞书凭证已保存"
            info "通知将写入 config.yaml 的 feishu 配置"
        else
            FEISHU_ENABLED=false
            info "跳过飞书配置"
        fi
    else
        FEISHU_ENABLED=false
        info "跳过飞书插件"
    fi
}

# ── 步骤 6: LLM 配置 ────────────────────────────────────────
step_llm() {
    echo ""
    echo -e "${BOLD}[6/9] LLM 配置${NC}"

    if [ -f "$OPENCLAW_DIR/openclaw.json" ] && ! $IS_UPDATE_MODE; then
        warn "检测到已有 openclaw.json"
        if ! ask_yes_no "是否覆盖现有配置？" "n"; then
            info "保留现有 LLM 配置"
            return
        fi
    fi

    echo ""
    echo -e "${BOLD}选择 LLM 服务商：${NC}"
    echo "  1) 百炼 Coding Plan — 通义千问系列 (qwen3-coder-plus)"
    echo "     API: https://coding.dashscope.aliyuncs.com"
    echo ""
    echo "  2) n1n.ai — GPT-4.1 + Claude Opus 4.1 (默认)"
    echo "     API: https://api.n1n.ai"
    echo "     文档: https://docs.n1n.ai/"
    echo ""

    local llm_choice="2"
    read -rp "  请选择 (1/2, 默认 2): " llm_choice
    llm_choice="${llm_choice:-2}"

    echo ""
    case "$llm_choice" in
        1)
            LLM_PROVIDER="百炼"
            info "请输入百炼 API Key:"
            read -rp "  API Key (sk-sp-xxx): " API_KEY
            ;;
        *)
            LLM_PROVIDER="n1n.ai"
            info "请输入 n1n.ai API Key:"
            read -rp "  API Key (sk-xxx): " API_KEY
            ;;
    esac

    if [ -z "$API_KEY" ]; then
        warn "未输入 API Key，将使用占位符（需后续手动填写）"
        API_KEY="{{YOUR_API_KEY}}"
    fi

    local tmpl=""
    case "$llm_choice" in
        1) tmpl="$DEPLOY_DIR/config/openclaw-bailian.json.template" ;;
        *) tmpl="$DEPLOY_DIR/config/openclaw-n1n.json.template" ;;
    esac

    if [ -f "$tmpl" ]; then
        local gw_token
        gw_token=$(openssl rand -hex 24 2>/dev/null || head -c 24 /dev/urandom | xxd -p)
        sed -e "s|{{API_KEY}}|$API_KEY|g" \
            -e "s|{{HOME}}|$HOME|g" \
            -e "s|{{GATEWAY_TOKEN}}|$gw_token|g" \
            "$tmpl" > "$OPENCLAW_DIR/openclaw.json"
        ok "openclaw.json 已生成 — $LLM_PROVIDER"
    else
        warn "模板文件不存在: $tmpl"
        warn "请手动创建 $OPENCLAW_DIR/openclaw.json"
    fi
}

# ── 步骤 7: 用户个性化 ──────────────────────────────────────
step_personalize() {
    echo ""
    echo -e "${BOLD}[7/9] 用户个性化${NC}"

    echo ""
    echo -e "${BOLD}👤 基本信息${NC}"
    ask_input "你希望 AI 怎么称呼你？" USER_DISPLAY_NAME "用户"
    ask_input "你所在的行业？" USER_INDUSTRY "通用"
    ask_input "你的视频风格？" USER_VIDEO_STYLE "通用"

    echo ""
    echo -e "${BOLD}🤖 AI 助手设定${NC}"
    ask_input "AI 名字？" AI_NAME "虾王"
    ask_input "AI 表情？" AI_EMOJI "🦐"
    ask_input "AI 性格风格？" AI_VIBE "轻松幽默直接，不啰嗦"

    echo ""
    if ask_yes_no "发起视频发布前需要你人工确认？（推荐 Yes）" "y"; then
        CONFIRM_BEFORE_PUBLISH="true"
    else
        CONFIRM_BEFORE_PUBLISH="false"
    fi

    ok "配置完成: 用户=$USER_DISPLAY_NAME | AI=$AI_NAME $AI_EMOJI"
}

# ── 步骤 7: 安装项目 + Skills + 配置文件 ───────────────────
step_projects() {
    echo ""
    echo -e "${BOLD}[8/9] 安装项目与 Skills${NC}"

    # 7.1 xiaolong-upload
    echo ""
    echo -e "${BOLD}  ▶ xiaolong-upload（视频号发布）${NC}"
    local xiaolong="$WORKSPACE_DIR/xiaolong-upload"

    if [ -d "$xiaolong" ]; then
        ok "已存在"
        if [ -d "$xiaolong/.git" ] && ask_yes_no "是否拉取最新代码？"; then
            cd "$xiaolong" && git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || warn "git pull 失败"
            cd "$PROJECT_ROOT"
            ok "代码已更新"
        fi
    else
        if [ -d "$PROJECT_ROOT/xiaolong-upload" ]; then
            cp -R "$PROJECT_ROOT/xiaolong-upload" "$xiaolong"
            ok "已从本地复制"
        else
            warn "xiaolong-upload 目录不存在，跳过"
        fi
    fi

    if [ -f "$xiaolong/requirements.txt" ]; then
        info "安装 Python 依赖..."
        cd "$xiaolong"
        "$PYTHON_CMD" -m venv .venv 2>/dev/null || true
        .venv/bin/pip install -r requirements.txt -q 2>/dev/null || true
        cd "$PROJECT_ROOT"
        ok "依赖已安装"
    fi

    # 7.2 openclaw_upload
    echo ""
    echo -e "${BOLD}  ▶ openclaw_upload（图生视频）${NC}"
    local oc_upload="$WORKSPACE_DIR/openclaw_upload"

    if [ -d "$oc_upload" ]; then
        ok "已存在"
        if [ -d "$oc_upload/.git" ] && ask_yes_no "是否拉取最新代码？"; then
            cd "$oc_upload" && git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || warn "git pull 失败"
            cd "$PROJECT_ROOT"
            ok "代码已更新"
        fi
    else
        if [ -d "$PROJECT_ROOT/openclaw_upload" ]; then
            cp -R "$PROJECT_ROOT/openclaw_upload" "$oc_upload"
            ok "已从本地复制"
        else
            warn "openclaw_upload 目录不存在，跳过"
        fi
    fi

    mkdir -p "$oc_upload/cookies" "$oc_upload/logs" "$oc_upload/published"
    mkdir -p "$oc_upload/flash_longxia/output"

    if [ -f "$oc_upload/requirements.txt" ]; then
        info "安装 Python 依赖..."
        cd "$oc_upload"
        "$PYTHON_CMD" -m venv .venv 2>/dev/null || true
        .venv/bin/pip install -r requirements.txt -q 2>/dev/null || true
        cd "$PROJECT_ROOT"
        ok "依赖已安装"
    fi

    # 7.3 生成 config.yaml
    echo ""
    echo -e "${BOLD}  ▶ 生成 flash_longxia/config.yaml${NC}"
    local cfg_yaml="$oc_upload/flash_longxia/config.yaml"
    mkdir -p "$(dirname "$cfg_yaml")"

    local feishu_block=""
    if $FEISHU_ENABLED && [ -n "$FEISHU_APP_ID" ]; then
        feishu_block="notify:
  channel: \"openclaw-weixin\"
  feishu:
    enabled: true
    app_id: \"$FEISHU_APP_ID\"
    app_secret: \"$FEISHU_APP_SECRET\"
    notify_on_complete: true
    notify_on_publish: true"
    else
        feishu_block="notify:
  channel: \"openclaw-weixin\"
  feishu:
    enabled: false"
    fi

    cat > "$cfg_yaml" << CONFIG_EOF
# 帧龙虾配置 — 由 install.sh 自动生成

base_url: "http://123.56.58.223:8081"
upload_url: "http://123.56.58.223:8081/api/v1/file/upload"
model_config_url: "http://123.56.58.223:8081/api/v1/globalConfig/getModel"

device_verify:
  enabled: false
  api_path: "/api/v1/device/verify"

video:
  poll_interval: 30
  max_wait_minutes: 30
  download_retries: 3
  download_retry_interval: 5
  output_dir: "./output"
  confirm_before_generate: $CONFIRM_BEFORE_PUBLISH
  model: "auto"
  duration: 10
  aspectRatio: "16:9"
  variants: 1

content:
  industry: "$USER_INDUSTRY"
  video_style: "$USER_VIDEO_STYLE"
  auto_generate_title: true
  auto_generate_description: true

$feishu_block
CONFIG_EOF
    ok "config.yaml 已生成"

    # 7.4 同步 Skills
    echo ""
    echo -e "${BOLD}  ▶ 同步 Skills${NC}"

    # 清理旧的嵌套结构
    for skill_dir in "$SKILLS_DIR"/*; do
        skill_name=$(basename "$skill_dir")
        if [ -d "$skill_dir/$skill_name" ]; then
            rm -rf "$skill_dir/$skill_name"
        fi
    done

    # 从 xiaolong-upload 同步
    local xiaolong_skills="$xiaolong/skills"
    if [ -d "$xiaolong_skills" ]; then
        for skill in auth longxia-upload video-cleanup; do
            if [ -d "$xiaolong_skills/$skill" ]; then
                cp -R "$xiaolong_skills/$skill/." "$SKILLS_DIR/$skill/" 2>/dev/null || true
                # 清理嵌套
                if [ -d "$SKILLS_DIR/$skill/$skill" ]; then
                    rm -rf "$SKILLS_DIR/$skill/$skill"
                fi
                ok "Skill [$skill] 已同步"
            fi
        done
    fi

    # 从 openclaw_upload 同步
    local oc_skills="$oc_upload/skills"
    if [ -d "$oc_skills" ]; then
        for skill in flash-longxia; do
            if [ -d "$oc_skills/$skill" ]; then
                cp -R "$oc_skills/$skill/." "$SKILLS_DIR/$skill/" 2>/dev/null || true
                if [ -d "$SKILLS_DIR/$skill/$skill" ]; then
                    rm -rf "$SKILLS_DIR/$skill/$skill"
                fi
                ok "Skill [$skill] 已同步"
            fi
        done
    fi

    # 禁用登录检查配置（用户不需要每日自动检查）
    local auth_cfg="$SKILLS_DIR/auth/login_check_config.json"
    if [ -f "$auth_cfg" ]; then
        python3 -c "
import json, sys
path='$auth_cfg'
data=json.load(open(path))
data['enabled']=False
with open(path,'w') as f:
    json.dump(data,f,indent=2,ensure_ascii=False)
    f.write('\n')
"
        ok "登录检查已禁用（登录失效时主动扫码即可）"
    fi
}

# ── 步骤 9: Workspace 配置 + 定时任务 + 验证 ────────────────
step_workspace_cron() {
    echo ""
    echo -e "${BOLD}[9/9] Workspace 配置与定时任务${NC}"

    # 8.1 Workspace 配置文件
    local ws_src="$DEPLOY_DIR/workspace"
    if [ -d "$ws_src" ]; then
        for f in AGENTS.md MEMORY.md HEARTBEAT.md TOOLS.md SOUL.md IDENTITY.md USER.md; do
            if [ -f "$ws_src/$f" ] && [ ! -f "$WORKSPACE_DIR/$f" ]; then
                sed -e "s|{{HOME}}|$HOME|g" \
                    -e "s|{{PYTHON_CMD}}|$PYTHON_CMD|g" \
                    -e "s|{{USER_NAME}}|$USER_DISPLAY_NAME|g" \
                    "$ws_src/$f" > "$WORKSPACE_DIR/$f"
            fi
        done
        ok "Workspace 配置文件已同步"
    fi

    # 8.2 生成 Workspace 配置文件（个性化部分）
    if [ ! -f "$WORKSPACE_DIR/IDENTITY.md" ]; then
        cat > "$WORKSPACE_DIR/IDENTITY.md" << EOF
# IDENTITY.md

- **Name:** $AI_NAME
- **Creature:** AI 助手
- **Vibe:** $AI_VIBE
- **Emoji:** $AI_EMOJI
EOF
        ok "IDENTITY.md 已生成"
    fi

    if [ ! -f "$WORKSPACE_DIR/USER.md" ]; then
        cat > "$WORKSPACE_DIR/USER.md" << EOF
# USER.md — 关于 $USER_DISPLAY_NAME

- **称呼:** $USER_DISPLAY_NAME
- **行业:** $USER_INDUSTRY
- **视频风格:** $USER_VIDEO_STYLE
- **主要平台:** 视频号
- **发布确认:** $([ "$CONFIRM_BEFORE_PUBLISH" = "true" ] && echo "需要人工确认" || echo "自动执行")
EOF
        ok "USER.md 已生成"
    fi

    # 8.3 创建 update-all.sh
    cat > "$WORKSPACE_DIR/update-all.sh" << 'UPDATE_EOF'
#!/bin/bash
set -e
echo "🔄 更新所有项目..."

WORKSPACE="$HOME/.openclaw/workspace"
SKILLS_DIR="$HOME/.openclaw/skills"
PYTHON_CMD="/opt/homebrew/bin/python3.12"

for repo in xiaolong-upload openclaw_upload; do
    repo_dir="$WORKSPACE/$repo"
    if [ -d "$repo_dir/.git" ]; then
        echo "  📦 $repo..."
        cd "$repo_dir"
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "  ⚠️ git pull 失败"
        if [ -d ".venv" ]; then
            .venv/bin/pip install -r requirements.txt -q 2>/dev/null || true
        fi
    fi
done

echo "  📋 Skills 同步..."
for skill in auth longxia-upload video-cleanup; do
    [ -d "$WORKSPACE/xiaolong-upload/skills/$skill" ] && \
        cp -R "$WORKSPACE/xiaolong-upload/skills/$skill/." "$SKILLS_DIR/$skill/" 2>/dev/null && \
        echo "  ✅ $skill"
done
for skill in flash-longxia; do
    [ -d "$WORKSPACE/openclaw_upload/skills/$skill" ] && \
        cp -R "$WORKSPACE/openclaw_upload/skills/$skill/." "$SKILLS_DIR/$skill/" 2>/dev/null && \
        echo "  ✅ $skill"
done

echo "✅ 更新完成！"
UPDATE_EOF
    chmod +x "$WORKSPACE_DIR/update-all.sh"
    ok "update-all.sh 已创建"

    # 8.4 定时任务：每周视频清理（无登录检查）
    echo ""
    echo -e "${BOLD}  ▶ 定时任务${NC}"

    local cleanup_day="2" cleanup_hour="01"
    read -rp "  每周几清理视频？(0=周日, 默认 2=周二): " input_day
    input_day="${input_day:-2}"
    cleanup_day="$input_day"
    read -rp "  几点执行清理？(默认 01:00): " input_hour
    input_hour="${input_hour:-01}"
    cleanup_hour="$input_hour"

    local now_ms
    now_ms=$(date +%s)000

    cat > "$OPENCLAW_DIR/cron/jobs.json" << CRON_EOF
{
  "version": 1,
  "jobs": [
    {
      "id": "$(uuidgen | tr '[:upper:]' '[:lower:]')",
      "agentId": "main",
      "sessionKey": "agent:main:main",
      "name": "video-cleanup-weekly",
      "enabled": true,
      "createdAtMs": $now_ms,
      "updatedAtMs": $now_ms,
      "schedule": {
        "kind": "cron",
        "expr": "0 $cleanup_hour * * $cleanup_day",
        "tz": "Asia/Shanghai"
      },
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": {
        "kind": "systemEvent",
        "text": "执行视频清理：cd ~/.openclaw/workspace && ${PYTHON_CMD:-python3.12} scripts/cleanup_uploaded_videos.py"
      },
      "state": { "consecutiveErrors": 0 }
    }
  ]
}
CRON_EOF
    ok "视频清理定时任务已创建（每周$cleanup_day 的 ${cleanup_hour}:00）"
    info "注：已关闭每日登录检查，登录失效时系统会主动发二维码到微信"
}

# ── 最终验证 ─────────────────────────────────────────────────
verify() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}验证结果${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local all_ok=true

    check_and_report() {
        local cond="$1"; local desc="$2"
        if eval "$cond"; then
            ok "$desc ✓"
        else
            fail "$desc ✗"
            all_ok=false
        fi
    }

    check_and_report "check_command openclaw" "OpenClaw"
    check_and_report "[ -x '$PYTHON_CMD' ] || check_command python3.12" "Python 3.12"
    check_and_report "[ -d '$WORKSPACE_DIR/xiaolong-upload' ]" "xiaolong-upload"
    check_and_report "[ -d '$WORKSPACE_DIR/openclaw_upload' ]" "openclaw_upload"
    check_and_report "[ -d '$SKILLS_DIR/auth' ]" "Skill [auth]"
    check_and_report "[ -d '$SKILLS_DIR/flash-longxia' ]" "Skill [flash-longxia]"
    check_and_report "[ -d '$SKILLS_DIR/longxia-upload' ]" "Skill [longxia-upload]"
    check_and_report "[ -d '$SKILLS_DIR/video-cleanup' ]" "Skill [video-cleanup]"

    echo ""
    if $all_ok; then
        echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}  ${BOLD}🎉 安装/更新完成！${NC}                ${GREEN}║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}╔══════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}  ${BOLD}⚠️  部分检查未通过，请处理后再试${NC}  ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════╝${NC}"
    fi

    echo ""
    echo -e "${BOLD}📋 后续步骤：${NC}"
    echo "  1. 启动 OpenClaw:      openclaw"
    echo "  2. 绑定微信:           openclaw channel connect openclaw-weixin"
    echo "  3. 配置 Token:         $WORKSPACE_DIR/openclaw_upload/flash_longxia/token.txt"
    echo "  4. 更新代码:           $WORKSPACE_DIR/update-all.sh"
    echo ""
    echo -e "${CYAN}  工作区: $WORKSPACE_DIR${NC}"
    echo -e "${CYAN}  Python: ${PYTHON_CMD:-python3.12}${NC}"
}

# ── 主函数 ────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}🦐 mac-upload 一键部署脚本${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  图生视频 + 视频号发布 + 微信通知${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"

    detect_mode
    step_system
    step_python
    step_openclaw
    step_wechat
    step_feishu
    step_llm
    step_personalize
    step_projects
    step_workspace_cron
    verify
}

main "$@"

#!/bin/bash
# ============================================================
# mac-openclaw 快速更新脚本
# 用于已安装环境，一键更新所有代码和 Skills
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

WORKSPACE="$HOME/.openclaw/workspace"
SKILLS_DIR="$HOME/.openclaw/skills"

echo ""
echo -e "${CYAN}🔄 mac-openclaw 快速更新${NC}"
echo ""

# 更新 xiaolong-upload
echo -e "${YELLOW}[1/3] xiaolong-upload${NC}"
if [ -d "$WORKSPACE/xiaolong-upload" ]; then
    cd "$WORKSPACE/xiaolong-upload"
    if [ -d ".git" ]; then
        git fetch origin 2>/dev/null
        LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null || echo "unknown")
        if [ "$LOCAL" != "$REMOTE" ]; then
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
            echo -e "  ${GREEN}✅ 代码已更新${NC}"
        else
            echo "  ℹ️  已是最新版本"
        fi
    else
        echo "  ⚠️  非 git 仓库，无法更新"
    fi
    # 更新依赖
    if [ -d ".venv" ] && [ -f "requirements.txt" ]; then
        .venv/bin/pip install -r requirements.txt -q 2>/dev/null
        echo -e "  ${GREEN}✅ 依赖已更新${NC}"
    fi
    cd - > /dev/null
else
    echo "  ❌ 未安装"
fi

# 更新 openclaw_upload
echo ""
echo -e "${YELLOW}[2/3] openclaw_upload${NC}"
if [ -d "$WORKSPACE/openclaw_upload" ]; then
    cd "$WORKSPACE/openclaw_upload"
    if [ -d ".git" ]; then
        git fetch origin 2>/dev/null
        LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null || echo "unknown")
        if [ "$LOCAL" != "$REMOTE" ]; then
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
            echo -e "  ${GREEN}✅ 代码已更新${NC}"
        else
            echo "  ℹ️  已是最新版本"
        fi
    else
        echo "  ⚠️  非 git 仓库，无法更新"
    fi
    # 更新依赖
    if [ -d ".venv" ] && [ -f "requirements.txt" ]; then
        .venv/bin/pip install -r requirements.txt -q 2>/dev/null
        echo -e "  ${GREEN}✅ 依赖已更新${NC}"
    fi
    cd - > /dev/null
else
    echo "  ❌ 未安装"
fi

# 同步 Skills
echo ""
echo -e "${YELLOW}[3/3] Skills 同步${NC}"
mkdir -p "$SKILLS_DIR"

skill_count=0
for skill in auth longxia-upload video-cleanup login-monitor; do
    if [ -d "$WORKSPACE/xiaolong-upload/skills/$skill" ]; then
        rm -rf "$SKILLS_DIR/$skill" 2>/dev/null || true
        cp -R "$WORKSPACE/xiaolong-upload/skills/$skill" "$SKILLS_DIR/$skill"
        skill_count=$((skill_count + 1))
        echo -e "  ${GREEN}✅ $skill${NC}"
    fi
done

for skill in flash-longxia; do
    if [ -d "$WORKSPACE/openclaw_upload/skills/$skill" ]; then
        rm -rf "$SKILLS_DIR/$skill" 2>/dev/null || true
        cp -R "$WORKSPACE/openclaw_upload/skills/$skill" "$SKILLS_DIR/$skill"
        skill_count=$((skill_count + 1))
        echo -e "  ${GREEN}✅ $skill${NC}"
    fi
done

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ✅ 更新完成！$skill_count 个 Skills 已同步${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
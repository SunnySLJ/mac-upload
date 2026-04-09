#!/bin/bash
# ============================================================
# mac-openclaw Python 环境安装脚本
# 仅安装 Python 依赖，不安装 OpenClaw
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${CYAN}🦐 mac-openclaw Python 环境安装${NC}"
echo ""

# 检测 Python 3.12
find_python312() {
    local candidates=(
        "/opt/homebrew/bin/python3.12"
        "/usr/local/bin/python3.12"
        "python3.12"
    )
    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            echo "$cmd"
            return 0
        fi
    done
    return 1
}

# 安装 xiaolong-upload (Python 3.10+)
echo -e "${YELLOW}[1/2] xiaolong-upload${NC}"
cd "$SCRIPT_DIR/xiaolong-upload"

if [ ! -d ".venv" ]; then
    echo "  创建虚拟环境..."
    python3 -m venv .venv
fi

echo "  安装依赖..."
.venv/bin/pip install -r requirements.txt -q 2>/dev/null || {
    echo "  ⚠️  使用国内镜像..."
    .venv/bin/pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
}
echo -e "  ${GREEN}✅ 完成${NC}"

# 安装 openclaw_upload (Python 3.12)
echo ""
echo -e "${YELLOW}[2/2] openclaw_upload${NC}"
cd "$SCRIPT_DIR/openclaw_upload"

PYTHON312=$(find_python312)
if [ -z "$PYTHON312" ]; then
    echo -e "  ${YELLOW}⚠️  未找到 Python 3.12，尝试安装...${NC}"
    if command -v brew &>/dev/null; then
        brew install python@3.12
        PYTHON312="/opt/homebrew/bin/python3.12"
    else
        echo "  ❌ 请先安装 Homebrew: https://brew.sh"
        exit 1
    fi
fi

if [ ! -d ".venv" ]; then
    echo "  创建虚拟环境..."
    $PYTHON312 -m venv .venv
fi

echo "  安装依赖..."
.venv/bin/pip install -r requirements.txt -q 2>/dev/null || {
    echo "  ⚠️  使用国内镜像..."
    .venv/bin/pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
}
echo -e "  ${GREEN}✅ 完成${NC}"

# 创建 output 目录
mkdir -p flash_longxia/output

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ✅ Python 环境安装完成！${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "使用方法:"
echo "  xiaolong-upload:  .venv/bin/python upload.py ..."
echo "  openclaw_upload:  .venv/bin/python flash_longxia/zhenlongxia_workflow.py ..."
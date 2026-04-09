#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
cd "${REPO_ROOT}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}mac-upload update${NC}"
echo ""

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Current directory is not a git repository."
  exit 2
fi

echo -e "${YELLOW}[1/4] Update mac-upload${NC}"
git fetch origin
CURRENT_BRANCH="$(git branch --show-current)"
if [[ -n "${CURRENT_BRANCH}" ]]; then
  git pull --ff-only origin "${CURRENT_BRANCH}"
else
  echo "Detached HEAD detected. Skip origin pull."
fi
echo -e "  ${GREEN}OK${NC}"

echo ""
echo -e "${YELLOW}[2/4] Sync subtree upstreams${NC}"
bash scripts/sync-upstreams.sh sync --bootstrap-if-needed
echo -e "  ${GREEN}OK${NC}"

echo ""
echo -e "${YELLOW}[3/4] Refresh local Python deps${NC}"
if [[ -d "xiaolong-upload/.venv" && -f "xiaolong-upload/requirements.txt" ]]; then
  xiaolong-upload/.venv/bin/pip install -r xiaolong-upload/requirements.txt -q || true
  echo -e "  ${GREEN}xiaolong-upload deps refreshed${NC}"
else
  echo "  Skip xiaolong-upload deps"
fi

if [[ -d "openclaw_upload/.venv" && -f "openclaw_upload/requirements.txt" ]]; then
  openclaw_upload/.venv/bin/pip install -r openclaw_upload/requirements.txt -q || true
  echo -e "  ${GREEN}openclaw_upload deps refreshed${NC}"
else
  echo "  Skip openclaw_upload deps"
fi

echo ""
echo -e "${YELLOW}[4/4] Done${NC}"
git status --short
echo ""
echo -e "${GREEN}Update complete.${NC}"

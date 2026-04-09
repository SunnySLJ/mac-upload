#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="${1:-${OPENCLAW_HOME:-/root/.openclaw}}"
BUNDLE_ROOT="${2:-${OPENCLAW_BUNDLE:-/opt/openclaw-bundle}}"
SKILLS_DIR="${TARGET_ROOT}/skills"
WORKSPACE_DIR="${TARGET_ROOT}/workspace"

copy_skill() {
    local src="$1"
    local name="$2"
    local dest="${SKILLS_DIR}/${name}"

    if [ ! -d "$src" ]; then
        return
    fi

    mkdir -p "$dest"
    cp -a "$src"/. "$dest"/
}

mkdir -p "$SKILLS_DIR"

for skill in flash-longxia auth longxia-upload longxia-bootstrap video-cleanup repo-sync; do
    copy_skill "${BUNDLE_ROOT}/skills/${skill}" "${skill}"
done

for skill in auth longxia-bootstrap longxia-upload; do
    copy_skill "${WORKSPACE_DIR}/xiaolong-upload/skills/${skill}" "${skill}"
done

copy_skill "${WORKSPACE_DIR}/openclaw_upload/skills/flash-longxia" "flash-longxia"


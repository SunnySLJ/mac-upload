#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-/root/.openclaw}"
OPENCLAW_SEED="${OPENCLAW_SEED:-/opt/openclaw-seed}"
OPENCLAW_BUNDLE="${OPENCLAW_BUNDLE:-/opt/openclaw-bundle}"
OPENCLAW_PROVIDER="${OPENCLAW_PROVIDER:-n1n}"
OPENCLAW_API_KEY="${OPENCLAW_API_KEY:-}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

copy_if_missing() {
    local src="$1"
    local dest="$2"

    mkdir -p "$dest"
    if [ -z "$(ls -A "$dest" 2>/dev/null)" ]; then
        cp -a "$src"/. "$dest"/
    fi
}

mkdir -p "$OPENCLAW_HOME"
copy_if_missing "$OPENCLAW_SEED" "$OPENCLAW_HOME"
copy_if_missing "$OPENCLAW_SEED/workspace" "$OPENCLAW_HOME/workspace"
copy_if_missing "$OPENCLAW_SEED/skills" "$OPENCLAW_HOME/skills"
copy_if_missing "$OPENCLAW_SEED/cron" "$OPENCLAW_HOME/cron"

if [ ! -f "$OPENCLAW_HOME/openclaw.json" ]; then
    python3 "${OPENCLAW_BUNDLE}/docker/init-config.py" \
        "$OPENCLAW_PROVIDER" \
        "$OPENCLAW_API_KEY" \
        "$OPENCLAW_GATEWAY_TOKEN" \
        "${OPENCLAW_BUNDLE}/config" \
        "$OPENCLAW_HOME/openclaw.json"
fi

mkdir -p \
    "$OPENCLAW_HOME/workspace" \
    "$OPENCLAW_HOME/skills" \
    "$OPENCLAW_HOME/cron" \
    "$OPENCLAW_HOME/memory" \
    "$OPENCLAW_HOME/memory-md" \
    "$OPENCLAW_HOME/workspace/inbound_images" \
    "$OPENCLAW_HOME/workspace/inbound_videos" \
    "$OPENCLAW_HOME/workspace/logs/auth_qr" \
    "$OPENCLAW_HOME/workspace/plugins"

if [ ! -x /usr/local/bin/openclaw-update-bundled-repos ]; then
    ln -sf "${OPENCLAW_BUNDLE}/docker/update-bundled-repos.sh" /usr/local/bin/openclaw-update-bundled-repos
fi

if [ ! -x /usr/local/bin/openclaw-sync-skills ]; then
    ln -sf "${OPENCLAW_BUNDLE}/docker/sync-skills.sh" /usr/local/bin/openclaw-sync-skills
fi

exec "$@"

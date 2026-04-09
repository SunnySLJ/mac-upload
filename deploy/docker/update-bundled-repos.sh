#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-/root/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_HOME}/workspace"
BUNDLE_ROOT="${OPENCLAW_BUNDLE:-/opt/openclaw-bundle}"

update_repo() {
    local repo_dir="$1"

    if [ ! -d "${repo_dir}/.git" ]; then
        echo "skip non-git directory: ${repo_dir}" >&2
        return
    fi

    git -C "$repo_dir" fetch --all --prune

    local branch
    branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)"
    if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
        branch="main"
    fi

    if git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
        git -C "$repo_dir" pull --ff-only origin "$branch"
        return
    fi

    if git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/main"; then
        git -C "$repo_dir" checkout main
        git -C "$repo_dir" pull --ff-only origin main
        return
    fi

    if git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/master"; then
        git -C "$repo_dir" checkout master
        git -C "$repo_dir" pull --ff-only origin master
        return
    fi

    echo "no tracked branch found for ${repo_dir}" >&2
    exit 1
}

install_python_requirements() {
    local repo_dir="$1"
    if [ -f "${repo_dir}/requirements.txt" ]; then
        pip install --no-cache-dir -r "${repo_dir}/requirements.txt"
    fi
}

install_node_requirements() {
    local repo_dir="$1"
    if [ -f "${repo_dir}/package.json" ]; then
        npm install --prefix "$repo_dir"
    fi
}

for repo in \
    "${WORKSPACE_DIR}/xiaolong-upload" \
    "${WORKSPACE_DIR}/openclaw_upload"
do
    update_repo "$repo"
    install_python_requirements "$repo"
    install_node_requirements "$repo"
done

mkdir -p \
    "${WORKSPACE_DIR}/openclaw_upload/cookies" \
    "${WORKSPACE_DIR}/openclaw_upload/logs" \
    "${WORKSPACE_DIR}/openclaw_upload/published" \
    "${WORKSPACE_DIR}/openclaw_upload/flash_longxia/output" \
    "${WORKSPACE_DIR}/openclaw_upload/scripts"

if [ -f "${BUNDLE_ROOT}/scripts/cleanup_uploaded_videos.py" ]; then
    cp -f "${BUNDLE_ROOT}/scripts/cleanup_uploaded_videos.py" "${WORKSPACE_DIR}/openclaw_upload/scripts/cleanup_uploaded_videos.py"
    chmod +x "${WORKSPACE_DIR}/openclaw_upload/scripts/cleanup_uploaded_videos.py"
fi

"${BUNDLE_ROOT}/docker/sync-skills.sh" "${OPENCLAW_HOME}" "${BUNDLE_ROOT}"

echo "repositories updated and skills resynced"

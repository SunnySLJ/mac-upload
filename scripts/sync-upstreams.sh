#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

UPSTREAM_COUNT=2
UPSTREAM_NAMES=("deploy" "xiaolong-upload")
UPSTREAM_PREFIXES=("deploy" "xiaolong-upload")
UPSTREAM_REMOTES=("upstream-deploy" "upstream-xiaolong-upload")
UPSTREAM_URLS=(
  "https://github.com/SunnySLJ/deploy.git"
  "https://github.com/SunnySLJ/xiaolong-upload.git"
)
UPSTREAM_BRANCHES=("main" "main")

BOOTSTRAP_IF_NEEDED=0
TARGET_NAME=""
COMMAND="${1:-status}"
if [[ $# -gt 0 ]]; then
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap-if-needed)
      BOOTSTRAP_IF_NEEDED=1
      ;;
    --name)
      shift
      TARGET_NAME="${1:-}"
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

ensure_git_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1
}

ensure_clean_worktree() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree is not clean. Commit or stash changes first." >&2
    exit 2
  fi
}

ensure_remote() {
  local remote_name="$1"
  local remote_url="$2"

  if git remote get-url "${remote_name}" >/dev/null 2>&1; then
    git remote set-url "${remote_name}" "${remote_url}" >/dev/null 2>&1 || true
  else
    git remote add "${remote_name}" "${remote_url}"
  fi
}

fetch_remote() {
  local remote_name="$1"
  local remote_branch="$2"
  git fetch "${remote_name}" "${remote_branch}" >/dev/null
}

is_initialized() {
  local prefix="$1"
  local match
  match="$(git log --grep="^git-subtree-dir: ${prefix}\$" -n 1 --format=%H HEAD 2>/dev/null || true)"
  [[ -n "${match}" ]]
}

copy_prefix_backup() {
  local prefix="$1"
  local backup_dir="$2"

  rm -rf "${backup_dir}"
  mkdir -p "$(dirname "${backup_dir}")"
  if [[ -d "${prefix}" ]]; then
    mkdir -p "${backup_dir}"
    cp -a "${prefix}/." "${backup_dir}/"
  fi
}

restore_prefix_backup() {
  local prefix="$1"
  local backup_dir="$2"

  if [[ -d "${backup_dir}" ]]; then
    mkdir -p "${prefix}"
    cp -a "${backup_dir}/." "${prefix}/"
  fi
}

bootstrap_upstream() {
  local name="$1"
  local prefix="$2"
  local remote_name="$3"
  local remote_branch="$4"
  local backup_dir=".codex_tmp/subtree-bootstrap/${name}"

  echo "[bootstrap] ${name}"
  ensure_clean_worktree
  copy_prefix_backup "${prefix}" "${backup_dir}"

  if [[ -e "${prefix}" ]]; then
    git rm -r -q -- "${prefix}"
    git commit -m "chore(subtree): prepare ${name} bootstrap" >/dev/null
  fi

  git subtree add --prefix="${prefix}" "${remote_name}" "${remote_branch}" --squash \
    -m "chore(subtree): add ${name} subtree" >/dev/null

  restore_prefix_backup "${prefix}" "${backup_dir}"
  git add "${prefix}"
  if ! git diff --cached --quiet -- "${prefix}"; then
    git commit -m "chore(subtree): reapply local ${name} customizations" >/dev/null
  fi
}

pull_upstream() {
  local name="$1"
  local prefix="$2"
  local remote_name="$3"
  local remote_branch="$4"

  ensure_remote "${remote_name}" "$(remote_url_for "${name}")"
  fetch_remote "${remote_name}" "${remote_branch}"

  if ! is_initialized "${prefix}"; then
    if [[ "${BOOTSTRAP_IF_NEEDED}" == "1" ]]; then
      bootstrap_upstream "${name}" "${prefix}" "${remote_name}" "${remote_branch}"
    else
      echo "[skip] ${name}: subtree metadata missing. Run bootstrap first."
      return 0
    fi
  fi

  local before
  before="$(git rev-parse HEAD)"
  git subtree pull --prefix="${prefix}" "${remote_name}" "${remote_branch}" --squash \
    -m "chore(subtree): sync ${name} from ${remote_branch}" >/dev/null
  local after
  after="$(git rev-parse HEAD)"

  if [[ "${before}" == "${after}" ]]; then
    echo "[ok] ${name}: already up to date"
  else
    echo "[ok] ${name}: synced"
  fi
}

status_upstream() {
  local name="$1"
  local prefix="$2"
  local remote_name="$3"
  local remote_branch="$4"

  ensure_remote "${remote_name}" "$(remote_url_for "${name}")"
  fetch_remote "${remote_name}" "${remote_branch}"

  local initialized="no"
  if is_initialized "${prefix}"; then
    initialized="yes"
  fi

  local remote_head
  remote_head="$(git rev-parse "${remote_name}/${remote_branch}")"
  echo "${name}: prefix=${prefix} initialized=${initialized} remote=${remote_head}"
}

remote_url_for() {
  local target_name="$1"
  local i
  for ((i = 0; i < UPSTREAM_COUNT; i += 1)); do
    if [[ "${UPSTREAM_NAMES[$i]}" == "${target_name}" ]]; then
      echo "${UPSTREAM_URLS[$i]}"
      return 0
    fi
  done
  return 1
}

for_each_upstream() {
  local handler="$1"
  local i
  for ((i = 0; i < UPSTREAM_COUNT; i += 1)); do
    local name="${UPSTREAM_NAMES[$i]}"
    if [[ -n "${TARGET_NAME}" && "${TARGET_NAME}" != "${name}" ]]; then
      continue
    fi
    "${handler}" \
      "${name}" \
      "${UPSTREAM_PREFIXES[$i]}" \
      "${UPSTREAM_REMOTES[$i]}" \
      "${UPSTREAM_BRANCHES[$i]}"
  done
}

main() {
  if ! ensure_git_repo; then
    echo "Current directory is not a git repository." >&2
    exit 2
  fi

  case "${COMMAND}" in
    status)
      for_each_upstream status_upstream
      ;;
    bootstrap)
      BOOTSTRAP_IF_NEEDED=1
      for_each_upstream pull_upstream
      ;;
    pull|sync)
      for_each_upstream pull_upstream
      ;;
    *)
      echo "Usage: scripts/sync-upstreams.sh [status|bootstrap|pull|sync] [--bootstrap-if-needed] [--name <upstream>]" >&2
      exit 2
      ;;
  esac
}

main

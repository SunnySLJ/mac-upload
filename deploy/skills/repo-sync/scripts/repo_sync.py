#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve()
SKILL_DIR = SCRIPT_PATH.parent.parent
CONFIG_PATH = SKILL_DIR / "repo_sync_config.json"


class RepoSyncError(Exception):
    pass


def load_config():
    if not CONFIG_PATH.exists():
        return {
            "default_repo": "",
            "default_remote": "origin",
            "default_branch": "",
        }
    with CONFIG_PATH.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def save_config(config):
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CONFIG_PATH.open("w", encoding="utf-8") as fh:
        json.dump(config, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def run_git(repo: Path, args, check=True):
    cmd = ["git", "-C", str(repo), *args]
    result = subprocess.run(cmd, text=True, capture_output=True)
    if check and result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "git command failed"
        raise RepoSyncError(message)
    return result


def resolve_repo(path_arg, config):
    candidate = path_arg or config.get("default_repo") or str(Path.cwd())
    repo = Path(candidate).expanduser().resolve()
    if not repo.exists():
        raise RepoSyncError(f"repo path does not exist: {repo}")
    probe = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "--show-toplevel"],
        text=True,
        capture_output=True,
    )
    if probe.returncode != 0:
        raise RepoSyncError(f"not a git repository: {repo}")
    return Path(probe.stdout.strip())


def get_branch(repo: Path):
    result = run_git(repo, ["rev-parse", "--abbrev-ref", "HEAD"])
    return result.stdout.strip()


def get_upstream(repo: Path):
    result = run_git(
        repo,
        ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def get_remote_url(repo: Path, remote: str):
    result = run_git(repo, ["remote", "get-url", remote], check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def get_dirty_files(repo: Path):
    result = run_git(repo, ["status", "--porcelain"])
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    return lines


def get_ahead_behind(repo: Path, upstream: str):
    if not upstream:
        return 0, 0
    result = run_git(repo, ["rev-list", "--left-right", "--count", f"HEAD...{upstream}"])
    ahead_str, behind_str = result.stdout.strip().split()
    return int(ahead_str), int(behind_str)


def print_status(repo: Path, remote: str):
    branch = get_branch(repo)
    upstream = get_upstream(repo)
    dirty_files = get_dirty_files(repo)
    ahead, behind = get_ahead_behind(repo, upstream)
    remote_url = get_remote_url(repo, remote)

    print(f"repo: {repo}")
    print(f"branch: {branch}")
    print(f"remote: {remote}")
    print(f"remote_url: {remote_url or '(not found)'}")
    print(f"upstream: {upstream or '(not configured)'}")
    print(f"ahead: {ahead}")
    print(f"behind: {behind}")
    print(f"dirty: {'yes' if dirty_files else 'no'}")
    if dirty_files:
        print("dirty_files:")
        for line in dirty_files:
            print(f"  {line}")


def command_show_config(_args):
    print(json.dumps(load_config(), ensure_ascii=False, indent=2))


def command_set_repo(args):
    config = load_config()
    repo = resolve_repo(args.repo, config)
    config["default_repo"] = str(repo)
    config["default_remote"] = args.remote
    config["default_branch"] = args.branch or ""
    save_config(config)
    print(f"default_repo: {repo}")
    print(f"default_remote: {args.remote}")
    print(f"default_branch: {args.branch or '(current branch)'}")


def command_status(args):
    config = load_config()
    repo = resolve_repo(args.repo, config)
    remote = args.remote or config.get("default_remote") or "origin"
    print_status(repo, remote)


def command_sync(args):
    config = load_config()
    repo = resolve_repo(args.repo, config)
    remote = args.remote or config.get("default_remote") or "origin"
    branch = args.branch or config.get("default_branch") or get_branch(repo)
    dirty_files = get_dirty_files(repo)

    if dirty_files and not args.allow_dirty:
        raise RepoSyncError("working tree is dirty; commit/stash changes or rerun with --allow-dirty")

    before_head = run_git(repo, ["rev-parse", "HEAD"]).stdout.strip()
    run_git(repo, ["fetch", "--prune", remote])
    pull_args = ["pull", "--ff-only", remote, branch]
    pull_result = run_git(repo, pull_args)
    after_head = run_git(repo, ["rev-parse", "HEAD"]).stdout.strip()

    print(f"repo: {repo}")
    print(f"remote: {remote}")
    print(f"branch: {branch}")
    print(f"before: {before_head}")
    print(f"after: {after_head}")
    print(f"updated: {'yes' if before_head != after_head else 'no'}")
    stdout = pull_result.stdout.strip()
    stderr = pull_result.stderr.strip()
    if stdout:
        print("pull_stdout:")
        print(stdout)
    if stderr:
        print("pull_stderr:")
        print(stderr)


def build_parser():
    parser = argparse.ArgumentParser(description="Check and sync a git repository safely.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    show_config = subparsers.add_parser("show-config")
    show_config.set_defaults(func=command_show_config)

    set_repo = subparsers.add_parser("set-repo")
    set_repo.add_argument("repo", help="Absolute or relative path to the git repository")
    set_repo.add_argument("--remote", default="origin", help="Default remote name")
    set_repo.add_argument("--branch", help="Default branch to sync")
    set_repo.set_defaults(func=command_set_repo)

    status = subparsers.add_parser("status")
    status.add_argument("--repo", help="Target git repository path")
    status.add_argument("--remote", help="Remote name, default from config or origin")
    status.set_defaults(func=command_status)

    sync = subparsers.add_parser("sync")
    sync.add_argument("--repo", help="Target git repository path")
    sync.add_argument("--remote", help="Remote name, default from config or origin")
    sync.add_argument("--branch", help="Branch name, default from config or current branch")
    sync.add_argument(
        "--allow-dirty",
        action="store_true",
        help="Allow sync even if the working tree has local modifications",
    )
    sync.set_defaults(func=command_sync)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.func(args)
    except RepoSyncError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

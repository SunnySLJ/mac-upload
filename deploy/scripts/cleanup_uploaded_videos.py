#!/usr/bin/env python3
"""Clean up generated video files based on the flash-longxia cleanup config."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from datetime import datetime
from pathlib import Path


def log(level: str, message: str) -> None:
    print(f"[{level}] {message}")


def load_config(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        log("WARN", f"读取配置失败，使用默认值: {path} ({exc})")
        return {}


def resolve_output_dir(project_root: Path, configured_path: str) -> Path:
    output_path = Path(configured_path).expanduser()
    if output_path.is_absolute():
        return output_path
    return (project_root / output_path).resolve()


def move_to_trash(path: Path) -> bool:
    trash_dir = Path.home() / ".Trash"
    if not trash_dir.exists():
        return False
    target = trash_dir / path.name
    if target.exists():
        target = trash_dir / f"{path.stem}_{int(time.time())}{path.suffix}"
    shutil.move(str(path), str(target))
    return True


def cleanup_videos(output_dir: Path, keep_days: int, delete_method: str, dry_run: bool) -> tuple[int, int]:
    cutoff_ts = time.time() - keep_days * 86400
    deleted_count = 0
    deleted_bytes = 0

    for file_path in sorted(output_dir.glob("*.mp4")):
        try:
            stat = file_path.stat()
        except FileNotFoundError:
            continue
        if stat.st_mtime >= cutoff_ts:
            continue

        deleted_count += 1
        deleted_bytes += stat.st_size
        size_mb = stat.st_size / (1024 * 1024)
        action = "DRYRUN"

        if not dry_run:
            if delete_method == "trash" and move_to_trash(file_path):
                action = "TRASHED"
            else:
                file_path.unlink()
                action = "DELETED"

        log(action, f"{file_path.name} ({size_mb:.2f} MB)")

    return deleted_count, deleted_bytes


def default_config_path(workspace_root: Path) -> Path:
    return workspace_root.parent / "skills" / "flash-longxia" / "cleanup_config.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clean up generated mp4 files.")
    parser.add_argument("--workspace-root", default=str(Path.home() / ".openclaw" / "workspace"))
    parser.add_argument("--project-root", default=None)
    parser.add_argument("--config", default=None)
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--keep-days", type=int, default=None)
    parser.add_argument("--delete-method", choices=["trash", "delete"], default=None)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    workspace_root = Path(args.workspace_root).expanduser().resolve()
    project_root = Path(args.project_root).expanduser().resolve() if args.project_root else workspace_root / "openclaw_upload"
    config_path = Path(args.config).expanduser().resolve() if args.config else default_config_path(workspace_root)
    config = load_config(config_path)
    output_cfg = config.get("output_cleanup", {})

    if output_cfg and not output_cfg.get("enabled", True):
        log("INFO", "输出目录清理已禁用，跳过")
        return 0

    keep_days = args.keep_days if args.keep_days is not None else int(output_cfg.get("keep_days", 7))
    delete_method = args.delete_method or output_cfg.get("delete_method", "trash")
    dry_run = bool(args.dry_run or output_cfg.get("dry_run", False))
    configured_output_dir = args.output_dir or output_cfg.get("output_dir", "flash_longxia/output")
    output_dir = resolve_output_dir(project_root, configured_output_dir)

    print("=" * 50)
    log("START", "视频清理任务启动")
    log("START", f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    log("INFO", f"输出目录: {output_dir}")
    log("INFO", f"保留最近 {keep_days} 天的视频")
    log("INFO", f"删除方式: {delete_method}")
    if dry_run:
        log("INFO", "当前为试运行模式，不会实际删除文件")

    if not output_dir.exists():
        log("INFO", "输出目录不存在，跳过")
        return 0

    deleted_count, deleted_bytes = cleanup_videos(output_dir, keep_days, delete_method, dry_run)
    print("-" * 50)
    log("SUMMARY", f"删除文件数: {deleted_count}")
    log("SUMMARY", f"释放空间: {deleted_bytes / (1024 * 1024):.2f} MB")
    log("SUMMARY", f"执行时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    log("SUCCESS", "清理任务完成")
    return 0


if __name__ == "__main__":
    sys.exit(main())

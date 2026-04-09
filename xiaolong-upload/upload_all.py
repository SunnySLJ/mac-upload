#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
视频号批量入口。

历史上这里曾承担多平台顺序发布，现在只保留视频号调用包装，
用于兼容旧脚本和批处理习惯。
"""
from __future__ import annotations

import sys
from pathlib import Path

_PROJECT_ROOT = Path(__file__).resolve().parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

from common.console import ensure_console_ready, safe_print
from common.python_runtime import ensure_preferred_python_3_11
from upload import SUPPORTED_PLATFORM, SUPPORTED_PLATFORMS, upload

ensure_preferred_python_3_11()
ensure_console_ready()

if sys.version_info < (3, 10):
    safe_print("错误: 需要 Python 3.10+")
    raise SystemExit(1)


PLATFORM_LABELS = {
    SUPPORTED_PLATFORM: "视频号",
}


def upload_all_platforms(
    video_path: str,
    title: str,
    description: str,
    tags: list[str],
    platforms: list[str] | None = None,
) -> dict[str, tuple[bool, str]]:
    selected_platforms = platforms or [SUPPORTED_PLATFORM]
    results: dict[str, tuple[bool, str]] = {}

    safe_print("=" * 60)
    safe_print("视频号发布任务")
    safe_print("=" * 60)
    safe_print(f"视频: {video_path}")
    safe_print(f"标题: {title}")
    safe_print(f"标签: {', '.join(tags) if tags else '(无)'}")
    safe_print("=" * 60)

    for platform in selected_platforms:
        label = PLATFORM_LABELS.get(platform, platform)
        safe_print(f"开始处理: {label}")
        success = upload(
            platform=platform,
            video_path=video_path,
            title=title,
            description=description,
            tags=tags,
            handle_login=True,
            close_browser=True,
        )
        results[platform] = (success, "发布成功" if success else "发布失败")
        safe_print(f"{label}: {'成功' if success else '失败'}")

    safe_print("=" * 60)
    success_count = sum(1 for success, _ in results.values() if success)
    safe_print(f"完成: {success_count}/{len(results)}")
    safe_print("=" * 60)

    return results


def _build_parser():
    import argparse

    parser = argparse.ArgumentParser(
        description="视频号发布批量入口（当前仅保留 shipinhao）",
    )
    parser.add_argument("video_path", help="视频文件路径")
    parser.add_argument("title", nargs="?", default="", help="标题")
    parser.add_argument("description", nargs="?", default="", help="文案")
    parser.add_argument("tags", nargs="?", default="", help="标签，逗号分隔")
    parser.add_argument(
        "--platforms",
        "-p",
        nargs="+",
        choices=SUPPORTED_PLATFORMS,
        default=None,
        help="保留旧参数形式，当前只接受 shipinhao",
    )
    parser.add_argument(
        "--platform",
        choices=SUPPORTED_PLATFORMS,
        help="单平台参数，当前只接受 shipinhao",
    )
    return parser


def _main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    tags = [tag.strip() for tag in args.tags.split(",") if tag.strip()]
    if args.platform:
        platforms = [args.platform]
    elif args.platforms:
        platforms = args.platforms
    else:
        platforms = [SUPPORTED_PLATFORM]

    results = upload_all_platforms(
        video_path=args.video_path,
        title=args.title,
        description=args.description,
        tags=tags,
        platforms=platforms,
    )
    return 0 if any(success for success, _ in results.values()) else 1


if __name__ == "__main__":
    raise SystemExit(_main())

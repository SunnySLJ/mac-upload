#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
龙虾上传统一入口。

当前仓库只对外开放视频号发布能力，其他平台实现保留在仓库中，
但不会再通过根 CLI 或根模块暴露。
"""
from __future__ import annotations

import sys
from pathlib import Path

_PROJECT_ROOT = Path(__file__).resolve().parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

from common.console import ensure_console_ready, safe_print
from common.platform_auth import check_platform_login, ensure_platform_login
from common.python_runtime import ensure_preferred_python_3_11

try:
    from skills.auth.scripts.platform_login import close_connect_browser
except ImportError:
    close_connect_browser = None

ensure_preferred_python_3_11()
ensure_console_ready()

if sys.version_info < (3, 10):
    safe_print("错误: 需要 Python 3.10+")
    raise SystemExit(1)


SUPPORTED_PLATFORM = "shipinhao"
SUPPORTED_PLATFORMS = (SUPPORTED_PLATFORM,)


def _dispatch_shipinhao(
    video_path: str,
    title: str,
    description: str,
    tags: list[str],
    **kwargs,
) -> bool:
    from platforms.shipinhao_upload.api import upload_to_shipinhao

    return upload_to_shipinhao(
        video_path=video_path,
        title=title,
        description=description,
        tags=tags,
        **kwargs,
    )


_DISPATCH = {
    SUPPORTED_PLATFORM: _dispatch_shipinhao,
}


def _normalize_platform(platform: str) -> str:
    return (platform or "").strip().lower()


def upload(
    platform: str,
    video_path: str,
    title: str = "",
    description: str = "",
    tags: list[str] | None = None,
    account_name: str = "default",
    handle_login: bool = True,
    notify_login_wechat: bool = False,
    login_only: bool = False,
    close_browser: bool = True,
) -> bool:
    """
    统一上传入口。

    当前仅支持 `shipinhao`。
    """
    normalized_platform = _normalize_platform(platform)
    if normalized_platform not in _DISPATCH:
        safe_print(
            f"错误: 当前只开放视频号发布，收到平台: {platform or '<empty>'}。"
        )
        safe_print("请使用 --platform shipinhao。")
        return False

    normalized_tags = [tag.strip() for tag in (tags or []) if tag and tag.strip()]

    if handle_login:
        ok, msg = ensure_platform_login(
            normalized_platform,
            project_root=_PROJECT_ROOT,
            timeout=300,
            notify_wechat=notify_login_wechat,
        )
    else:
        ok, msg = check_platform_login(
            normalized_platform,
            project_root=_PROJECT_ROOT,
            passive=True,
        )

    if not ok:
        safe_print(f"错误: {msg}")
        return False

    safe_print(msg)

    if login_only:
        safe_print("视频号登录检查完成，按要求不继续发布。")
        return True

    ok = _DISPATCH[normalized_platform](
        video_path=video_path,
        title=title,
        description=description,
        tags=normalized_tags,
        account_name=account_name,
        handle_login=False,
    )

    if ok and close_connect_browser and close_browser:
        safe_print("视频号发布成功，准备关闭 connect Chrome...")
        try:
            close_connect_browser(normalized_platform)
            safe_print("视频号 connect Chrome 已关闭")
        except Exception as exc:
            safe_print(f"警告: 关闭浏览器失败: {exc}")

    return ok


def _build_parser():
    import argparse

    parser = argparse.ArgumentParser(
        description="龙虾上传统一入口（当前仅开放视频号）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python upload.py --platform shipinhao video.mp4 "标题" "文案" "标签1,标签2"
  python upload.py -p shipinhao video.mp4 --login-only
        """.strip(),
    )
    parser.add_argument(
        "--platform",
        "-p",
        required=True,
        choices=SUPPORTED_PLATFORMS,
        help="目标平台；当前仅支持 shipinhao",
    )
    parser.add_argument("video_path", help="视频文件路径")
    parser.add_argument("title", nargs="?", default="", help="标题")
    parser.add_argument("description", nargs="?", default="", help="文案")
    parser.add_argument("tags", nargs="?", default="", help="标签，逗号分隔")
    parser.add_argument("--account", default="default", help="账号名")
    parser.add_argument(
        "--no-login",
        action="store_true",
        help="若当前会话不可复用，则不自动拉起登录流程",
    )
    parser.add_argument(
        "--notify-login-wechat",
        action="store_true",
        help="登录失效时把二维码发到微信",
    )
    parser.add_argument(
        "--login-only",
        action="store_true",
        help="只完成登录检查/补登录，不继续发布",
    )
    return parser


def _main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    tags = [tag.strip() for tag in args.tags.split(",") if tag.strip()]
    ok = upload(
        platform=args.platform,
        video_path=args.video_path,
        title=args.title,
        description=args.description,
        tags=tags,
        account_name=args.account,
        handle_login=not args.no_login,
        notify_login_wechat=args.notify_login_wechat,
        login_only=args.login_only,
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(_main())

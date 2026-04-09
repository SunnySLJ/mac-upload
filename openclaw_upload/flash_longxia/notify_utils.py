#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通知相关公共工具，供轮询和补发脚本复用。"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from zhenlongxia_workflow import load_config


def resolve_notify_settings() -> tuple[str | None, str | None]:
    """从环境变量或 config.yaml 读取通知配置。"""
    env_target = (os.getenv("FLASH_LONGXIA_WECHAT_TARGET") or os.getenv("OPENCLAW_WECHAT_TARGET") or "").strip()
    env_channel = (os.getenv("FLASH_LONGXIA_NOTIFY_CHANNEL") or "").strip()
    if env_target:
        return env_target, env_channel or None

    config = load_config()
    notify_cfg = config.get("notify", {}) or {}
    target = str(notify_cfg.get("wechat_target") or "").strip()
    channel = str(notify_cfg.get("channel") or "").strip()
    return (target or None, channel or None)


def load_processed_ids(path: Path) -> set[str]:
    if not path.exists():
        return set()
    try:
        return {str(item) for item in json.loads(path.read_text(encoding="utf-8"))}
    except json.JSONDecodeError:
        return set()


def save_processed_ids(path: Path, processed: set[str]) -> None:
    path.write_text(
        json.dumps(sorted(processed), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def send_wechat_notification(
    task_id: str,
    *,
    video_path: str | None = None,
    message: str,
    follow_up: str,
    video_message: str | None = None,
    text_timeout: int = 30,
    media_timeout: int = 120,
) -> bool:
    """发送文本通知；若提供 video_path 则继续发送视频文件。"""
    wechat_target, notify_channel = resolve_notify_settings()
    if not wechat_target:
        print("[通知] 未配置微信目标，跳过发送")
        return False

    notify_text = (
        "🦐 **视频生成完成通知**\n\n"
        f"✅ 任务 {task_id} 已完成\n\n"
        f"{message}\n\n"
        "---\n"
        f"{follow_up}"
    )

    cmd_text = ["openclaw", "message", "send"]
    if notify_channel:
        cmd_text.extend(["--channel", notify_channel])
    cmd_text.extend([
        "--target", wechat_target,
        "--message", notify_text,
    ])

    try:
        result = subprocess.run(cmd_text, capture_output=True, text=True, timeout=text_timeout)
        if result.returncode == 0:
            print("[通知] 文本通知已发送")
        else:
            print(f"[通知] 文本通知发送失败：{result.stderr}")
    except Exception as e:
        print(f"[通知] 文本通知发送异常：{e}")

    if not video_path:
        return True

    cmd_media = ["openclaw", "message", "send"]
    if notify_channel:
        cmd_media.extend(["--channel", notify_channel])
    cmd_media.extend([
        "--target", wechat_target,
        "--media", video_path,
        "--message", video_message or f"📹 视频文件：任务 {task_id}",
    ])

    try:
        result = subprocess.run(cmd_media, capture_output=True, text=True, timeout=media_timeout)
        if result.returncode == 0:
            print("[通知] 视频文件已发送")
            return True
        print(f"[通知] 视频文件发送失败：{result.stderr}")
        return False
    except Exception as e:
        print(f"[通知] 视频文件发送异常：{e}")
        return False

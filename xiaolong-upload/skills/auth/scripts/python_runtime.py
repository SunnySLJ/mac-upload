#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""统一 Python 运行时选择。macOS 下优先切到 Homebrew Python 3.12。"""
from __future__ import annotations

import os
import platform
import sys
from pathlib import Path


PREFERRED_MAC_PYTHON = Path("/opt/homebrew/bin/python3.12")


def ensure_preferred_python_3_12() -> None:
    """在 macOS 下优先重进到 /opt/homebrew/bin/python3.12。"""
    if os.environ.get("XIAOLONG_PYTHON_LOCK") == "1":
        return
    if platform.system() != "Darwin":
        return
    if sys.version_info[:2] == (3, 12):
        return
    if not PREFERRED_MAC_PYTHON.exists():
        return

    env = os.environ.copy()
    env["XIAOLONG_PYTHON_LOCK"] = "1"
    os.execve(str(PREFERRED_MAC_PYTHON), [str(PREFERRED_MAC_PYTHON), *sys.argv], env)


# 兼容旧函数名
ensure_preferred_python_3_11 = ensure_preferred_python_3_12
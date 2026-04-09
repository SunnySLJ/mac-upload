#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
帧龙虾视频生成 - 技能封装脚本

用法:
    python generate_video.py <图片路径1> [图片路径2] [图片路径3] [图片路径4] [选项]
    python generate_video.py --list-models [--token=xxx]

示例:
    python generate_video.py --list-models
    python generate_video.py image.jpg --model=sora2-new --duration=10 --variants=1
    python generate_video.py img1.jpg img2.jpg img3.jpg img4.jpg --model=grok_imagine --duration=10 --yes
    python generate_video.py image.jpg --yes
"""

import sys
import os
from pathlib import Path

import requests
import yaml

def resolve_repo_root() -> Path | None:
    """优先从 cwd、环境变量和 OpenClaw 常见目录定位仓库。"""
    candidates: list[Path] = []

    env_root = os.environ.get("OPENCLAW_UPLOAD_ROOT")
    if env_root:
        candidates.append(Path(env_root).expanduser())

    cwd = Path.cwd().resolve()
    candidates.extend([cwd, *cwd.parents])

    script_dir = Path(__file__).resolve().parent
    candidates.extend([script_dir, *script_dir.parents])

    home = Path.home()
    candidates.extend([
        home / ".openclaw" / "workspace" / "openclaw_upload",
        home / "Desktop" / "openclaw_upload",
        home / "workspace" / "openclaw_upload",
        home / "openclaw_upload",
    ])

    for candidate in candidates:
        try:
            candidate = candidate.resolve()
        except FileNotFoundError:
            continue

        workflow = candidate / "flash_longxia" / "zhenlongxia_workflow.py"
        if workflow.exists():
            return candidate
    return None


repo_root = resolve_repo_root()
if repo_root is None:
    print("错误：找不到 openclaw_upload 仓库根目录，请在项目目录运行，或设置 OPENCLAW_UPLOAD_ROOT 指向包含 flash_longxia 的目录")
    sys.exit(1)


def ensure_project_venv() -> None:
    """优先切换到仓库内的 .venv Python，避免依赖缺失。"""
    venv_root = repo_root / ".venv"
    venv_python = venv_root / "bin" / "python3.12"
    if not venv_python.exists():
        return

    if Path(sys.prefix).resolve() == venv_root.resolve():
        return

    os.execv(str(venv_python), [str(venv_python), *sys.argv])


ensure_project_venv()

if sys.version_info[:2] != (3, 12):
    print(f"错误：当前 Python 版本是 {sys.version.split()[0]}，请改用 python3.12 运行")
    sys.exit(1)

workflow_path = repo_root / "flash_longxia" / "zhenlongxia_workflow.py"

if not workflow_path.exists():
    print(f"错误：找不到工作流脚本 {workflow_path}")
    sys.exit(1)

# 导入工作流模块
sys.path.insert(0, str(workflow_path.parent))
from zhenlongxia_workflow import (
    fetch_model_options,
    fetch_template_categories,
    fetch_template_options,
    find_template_category_by_name,
    load_config,
    load_saved_token,
    print_model_options,
    run_workflow,
)


def load_runtime_config() -> dict:
    """读取 openclaw_upload/flash_longxia/config.yaml。"""
    config_path = repo_root / "flash_longxia" / "config.yaml"
    if not config_path.exists():
        return {}
    with config_path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def normalize_match_text(value: object) -> str:
    """归一化模板匹配文本，便于做宽松匹配。"""
    raw = str(value or "").strip().lower()
    return "".join(ch for ch in raw if not ch.isspace() and ch not in "-_/")


def extract_template_id(item: dict) -> int | None:
    template_id = (
        item.get("id")
        or item.get("tmpplateId")
        or item.get("templateId")
        or item.get("aiTemplateId")
    )
    if template_id is None:
        return None
    try:
        return int(template_id)
    except (TypeError, ValueError):
        return None


def get_configured_template_name(config: dict) -> tuple[bool, str]:
    """从 config.yaml 读取默认行业模板配置。"""
    content_cfg = config.get("content") or {}
    template_cfg = content_cfg.get("industry_template") or {}

    if isinstance(template_cfg, dict):
        enabled = bool(template_cfg.get("enabled", False))
        template_name = str(template_cfg.get("name") or "").strip()
    else:
        enabled = bool(content_cfg.get("industry_template_enabled", False))
        template_name = str(content_cfg.get("industry_template_name") or "").strip()

    if enabled and not template_name:
        template_name = str(content_cfg.get("industry") or "").strip()
    return enabled, template_name


def fetch_all_template_options(base_url: str, session: requests.Session, tab_type: int) -> list[dict]:
    """分页拉取行业模板，避免只命中第一页。"""
    page_size = 100
    items: list[dict] = []
    seen_keys: set[str] = set()

    for page_num in range(1, 6):
        page_items = fetch_template_options(
            base_url,
            session,
            page_num=page_num,
            page_size=page_size,
            tab_type=tab_type,
        )
        if not page_items:
            break
        for item in page_items:
            template_id = extract_template_id(item)
            title = str(item.get("title") or "").strip()
            dedupe_key = f"{template_id}:{title}"
            if dedupe_key in seen_keys:
                continue
            seen_keys.add(dedupe_key)
            items.append(item)
        if len(page_items) < page_size:
            break
    return items


def resolve_template_from_config(
    workflow_config: dict,
    runtime_config: dict,
    token_val: str,
) -> tuple[int | None, str | None]:
    """按配置的模板名自动匹配行业模板。"""
    enabled, template_name = get_configured_template_name(runtime_config)
    if not enabled:
        return None, None
    if not template_name:
        print("[模板] 已启用行业模板，但没有配置模板名，跳过", flush=True)
        return None, None

    base_url = str(workflow_config.get("base_url") or "").rstrip("/")
    if not base_url:
        print("[模板] 缺少 base_url，无法解析行业模板", flush=True)
        return None, None

    session = requests.Session()
    session.headers.update({
        "token": token_val,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json",
    })

    category_items = fetch_template_categories(base_url, session, media_type=1)
    industry_category = find_template_category_by_name(category_items, tab_name="行业模板")
    if not industry_category or industry_category.get("tabType") is None:
        print("[模板] 未找到行业模板分类，跳过默认模板", flush=True)
        return None, None

    template_items = fetch_all_template_options(base_url, session, int(industry_category["tabType"]))
    if not template_items:
        print("[模板] 当前没有可用行业模板，跳过默认模板", flush=True)
        return None, None

    query = normalize_match_text(template_name)
    exact_match = None
    fuzzy_match = None
    for item in template_items:
        title = str(item.get("title") or "").strip()
        normalized_title = normalize_match_text(title)
        if not normalized_title:
            continue
        if normalized_title == query:
            exact_match = item
            break
        if query in normalized_title or normalized_title in query:
            fuzzy_match = fuzzy_match or item

    selected = exact_match or fuzzy_match
    if not selected:
        print(f"[模板] 未找到匹配的行业模板：{template_name}，将按原流程继续", flush=True)
        return None, None

    template_id = extract_template_id(selected)
    template_title = str(selected.get("title") or "").strip() or template_name
    if template_id is None:
        print(f"[模板] 模板 {template_title} 缺少 ID，跳过", flush=True)
        return None, None

    print(f"[模板] 已匹配默认行业模板: {template_title} (tmpplateId={template_id})", flush=True)
    return template_id, template_title

def main():
    if len(sys.argv) < 2:
        print("用法：python generate_video.py <图片路径1> [图片路径2] [图片路径3] [图片路径4] [选项]")
        print("      python generate_video.py --list-models [--token=xxx]")
        print()
        print("选项:")
        print("  --list-models     查询可用模型、时长与比例")
        print("  --token=xxx       Token（也可写入 token.txt）")
        print("  --model=MODEL     模型值，来自模型配置接口")
        print("  --duration=N      时长，需匹配所选模型")
        print("  --aspectRatio=X   比例，需匹配所选模型")
        print("  --variants=N      变体数量")
        print("  --templateId=ID   显式指定行业模板 ID")
        print("  --templateTitle=T 显式指定行业模板标题")
        print("  --yes             跳过发起视频前的人工确认")
        print("  说明              最多传 4 张图片，最终生成 1 个视频")
        sys.exit(1)

    image_paths: list[str] = []
    list_models = False

    # 解析参数
    kwargs = {}
    for arg in sys.argv[1:]:
        if arg == "--list-models":
            list_models = True
        elif arg.startswith("--token="):
            kwargs["token"] = arg.split("=", 1)[1]
        elif arg.startswith("--model="):
            kwargs["model"] = arg.split("=", 1)[1]
        elif arg.startswith("--duration="):
            kwargs["duration"] = int(arg.split("=", 1)[1])
        elif arg.startswith("--aspectRatio="):
            kwargs["aspectRatio"] = arg.split("=", 1)[1]
        elif arg.startswith("--variants="):
            kwargs["variants"] = int(arg.split("=", 1)[1])
        elif arg.startswith("--templateId="):
            kwargs["tmpplateId"] = int(arg.split("=", 1)[1])
        elif arg.startswith("--templateTitle="):
            kwargs["title"] = arg.split("=", 1)[1]
        elif arg == "--yes":
            kwargs["auto_confirm"] = True
        elif not arg.startswith("--"):
            image_paths.append(arg)

    if list_models:
        config = load_config()
        base_url = config["base_url"].rstrip("/")
        model_config_url = config.get("model_config_url", f"{base_url}/api/v1/globalConfig/getModel")
        token_val = kwargs.get("token") or load_saved_token()
        if not token_val:
            print("错误：请将 Token 写入 flash_longxia/token.txt 或使用 --token=xxx")
            sys.exit(1)

        session = requests.Session()
        session.headers.update({
            "token": token_val,
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept": "application/json",
        })
        model_items = fetch_model_options(base_url, session, model_config_url=model_config_url)
        print_model_options(model_items)
        return

    if not image_paths:
        print("错误：缺少图片路径")
        sys.exit(1)
    if len(image_paths) > 4:
        print(f"错误：最多只支持 4 张图片，当前传入 {len(image_paths)} 张")
        sys.exit(1)

    token_val = kwargs.get("token") or load_saved_token()
    if kwargs.get("tmpplateId") is None and token_val:
        try:
            workflow_config = load_config()
            runtime_config = load_runtime_config()
            template_id, template_title = resolve_template_from_config(
                workflow_config,
                runtime_config,
                token_val,
            )
            if template_id is not None:
                kwargs["tmpplateId"] = template_id
                kwargs["title"] = template_title
        except Exception as exc:
            print(f"[模板] 自动匹配默认行业模板失败：{exc}", flush=True)

    # 运行工作流
    try:
        task_id = run_workflow(image_paths, **kwargs)
        print(f"\n已提交视频生成任务，任务 ID：{task_id}")
    except SystemExit as e:
        sys.exit(e.code)
    except Exception as e:
        print(f"\n❌ 错误：{e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import json
import secrets
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 6:
        raise SystemExit("usage: init-config.py <provider> <api_key> <gateway_token> <template_root> <output_path>")

    provider, api_key, gateway_token, template_root, output_path = sys.argv[1:]
    template_name = {
        "n1n": "openclaw-n1n.json.template",
        "bailian": "openclaw-bailian.json.template",
    }.get(provider.lower())

    if template_name is None:
        raise SystemExit(f"unsupported provider: {provider}")

    template_path = Path(template_root) / template_name
    content = template_path.read_text(encoding="utf-8")

    gateway_token = gateway_token or secrets.token_hex(24)
    content = content.replace("{{API_KEY}}", api_key or "{{YOUR_API_KEY}}")
    content = content.replace("{{GATEWAY_TOKEN}}", gateway_token)

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(content + ("\n" if not content.endswith("\n") else ""), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

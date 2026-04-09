---
name: longxia-upload
description: 视频号上传技能。当用户提到“上传到视频号”“继续上传视频号”“重传视频号”“视频号登录后发布”时必须使用。当前只开放视频号，不处理其他平台。
---

# 龙虾上传 Skill

本技能只处理视频号上传。

## 当前范围

- 支持平台：`shipinhao`
- 根入口：`upload.py`
- 登录入口：`skills/auth/scripts/platform_login.py`
- 历史平台代码保留在仓库中，但不作为可调用能力

## 标准用法

登录检查：

```bash
${OPENCLAW_PYTHON:-python3.12} skills/auth/scripts/platform_login.py --project-root "${OPENCLAW_UPLOAD_ROOT:-<repo-root>}" --platform shipinhao --check-only
```

上传视频：

```bash
${OPENCLAW_PYTHON:-python3.12} upload.py --platform shipinhao "<视频路径>" "<标题>" "<文案>" "<标签1,标签2,...>"
```

只补登录不发布：

```bash
${OPENCLAW_PYTHON:-python3.12} upload.py --platform shipinhao "<视频路径>" --login-only
```

## 规则

1. 上传前必须先确认视频号登录可复用。
2. 如果登录失效，先走 `auth`，不要直接硬发。
3. 不要再引用抖音、快手、小红书的旧脚本或模板。
4. 如果用户要求其他平台，必须明确说明当前仓库未开放对应入口。

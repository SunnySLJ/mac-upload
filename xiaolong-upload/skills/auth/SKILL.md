---
name: auth
description: 视频号登录技能。当用户提到“登录视频号”“重新登录视频号”“视频号扫码登录”“视频号登录失效”“视频号会话过期”“先登录视频号再发布”时必须使用。只负责视频号 connect Chrome 的登录检查、补登录和会话复用，不负责实际发布。
---

# Auth Skill

本技能只处理视频号登录。

## 目标

1. 上传前检查视频号登录是否可复用。
2. 登录失效时拉起视频号专用 connect Chrome。
3. 登录完成后把会话稳定写入 `cookies/chrome_connect_sph`。
4. 登录完成后停在“可发布”状态，等待后续发布动作。

## 固定映射

- 平台：`shipinhao`
- 端口：`9226`
- 目录：`cookies/chrome_connect_sph`

## 入口

登录检查：

```bash
${OPENCLAW_PYTHON:-python3.12} skills/auth/scripts/platform_login.py --project-root "${OPENCLAW_UPLOAD_ROOT:-<repo-root>}" --platform shipinhao --check-only
```

打开登录：

```bash
${OPENCLAW_PYTHON:-python3.12} skills/auth/scripts/platform_login.py --project-root "${OPENCLAW_UPLOAD_ROOT:-<repo-root>}" --platform shipinhao
```

微信发二维码：

```bash
${OPENCLAW_PYTHON:-python3.12} skills/auth/scripts/platform_login.py --project-root "${OPENCLAW_UPLOAD_ROOT:-<repo-root>}" --platform shipinhao --notify-wechat
```

## 规则

1. 一次只处理视频号，不接受其他平台。
2. 本技能只负责登录，不直接执行发布。
3. 真正发布统一交给根入口 `upload.py`。
4. 如果用户提到其他平台，必须明确说明当前项目未开放对应入口。

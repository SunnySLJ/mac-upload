---
name: auth
description: 视频号登录技能。用于视频号登录检查、补登录、扫码登录和会话恢复。当前只开放视频号，不处理抖音、快手、小红书。
---

# Auth Skill

部署包里的 auth skill 只针对视频号。

## 固定映射

- 平台：`shipinhao`
- 端口：`9226`
- 目录：`cookies/chrome_connect_sph`

## 常用命令

```bash
/opt/homebrew/bin/python3.12 skills/auth/scripts/platform_login.py --project-root /Users/mima0000/.openclaw/workspace/xiaolong-upload --platform shipinhao --check-only
/opt/homebrew/bin/python3.12 skills/auth/scripts/platform_login.py --project-root /Users/mima0000/.openclaw/workspace/xiaolong-upload --platform shipinhao
/opt/homebrew/bin/python3.12 skills/auth/scripts/platform_login.py --project-root /Users/mima0000/.openclaw/workspace/xiaolong-upload --platform shipinhao --notify-wechat
```

## 规则

1. 只做登录检查和补登录。
2. 只接受 `shipinhao`。
3. 发布动作交给 `upload.py`。

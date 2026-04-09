# TOOLS.md - 本地配置与操作命令 (Mac/Windows 版)

## 当前开放平台

| 平台 | Chrome 端口 | Cookies 目录 |
|------|------------|-------------|
| 视频号 | 9226 | `cookies/chrome_connect_sph` |

> 注意：抖音、小红书、快手实现保留在仓库中，但当前不对外开放。

## 重要目录

| 用途 | Mac 路径 | Windows 路径 |
|------|----------|--------------|
| 图片保存 | `~/.openclaw/workspace/inbound_images/` | `%USERPROFILE%\.openclaw\workspace\inbound_images\` |
| 视频输出 | `~/.openclaw/workspace/openclaw_upload/flash_longxia/output/` | `%USERPROFILE%\.openclaw\workspace\openclaw_upload\flash_longxia\output\` |
| Cookies 保存 | `~/.openclaw/workspace/xiaolong-upload/cookies/` | `%USERPROFILE%\.openclaw\workspace\xiaolong-upload\cookies\` |
| 登录二维码 | `~/.openclaw/workspace/xiaolong-upload/logs/auth_qr/` | `%USERPROFILE%\.openclaw\workspace\xiaolong-upload\logs\auth_qr\` |

## Python 环境

| 项目 | Python 版本 | 虚拟环境 |
|------|-------------|----------|
| xiaolong-upload | 3.10+ | `.venv/bin/python` (Mac) / `.venv\Scripts\python.exe` (Windows) |
| openclaw_upload | 3.12 | `.venv/bin/python3.12` (Mac) / `.venv\Scripts\python.exe` (Windows) |

## 两个核心技能

### 1️⃣ 图片生成视频 - flash_longxia (帧龙虾)

```bash
cd ~/.openclaw/workspace/openclaw_upload

# 查询可用模型参数
.venv/bin/python3.12 flash_longxia/zhenlongxia_workflow.py --list-models

# 生成视频
.venv/bin/python3.12 flash_longxia/zhenlongxia_workflow.py <图片路径> --model=auto --duration=10 --aspectRatio=9:16 --yes
```

**流程**: 上传图片 → 图生文 → 生成视频任务 → 后台轮询 → 下载 MP4

### 2️⃣ 视频号发布

```bash
cd ~/.openclaw/workspace/xiaolong-upload

# 视频号上传
.venv/bin/python upload.py -p shipinhao "<视频路径>" "<标题>" "<文案>" "<标签>"
```

**生成前必读**：
- `IDENTITY.md`：当前助手的人设和 Vibe
- `SOUL.md`：说话风格和边界
- `USER.md`：用户偏好和表达要求

## 微信通知配置

- **微信 Target**: 通过环境变量 `OPENCLAW_WECHAT_TARGET` 配置
- **Channel**: `openclaw-weixin`
- **发送命令**: `openclaw message send --channel=openclaw-weixin -t "<target>" -m "消息内容"`

### 配置微信 Target

```bash
# Mac (添加到 ~/.zshrc 或 ~/.zprofile)
export OPENCLAW_WECHAT_TARGET="your_target@im.wechat"

# Windows (PowerShell)
$env:OPENCLAW_WECHAT_TARGET = "your_target@im.wechat"
```

获取 Target: 绑定微信后执行 `openclaw channel list` 查看

---
_请根据实际环境修改配置_
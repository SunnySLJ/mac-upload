# TOOLS.md - 本地配置与操作命令

## 平台端口配置

| 平台 | Chrome 端口 | Cookies 目录 |
|------|------------|-------------|
| 抖音 | 9224 | `cookies/chrome_connect_dy` |
| 小红书 | 9223 | `cookies/chrome_connect_xhs` |
| 快手 | 9225 | `cookies/chrome_connect_ks` |
| 视频号 | 9226 | `cookies/chrome_connect_sph` |

## 重要目录

| 用途 | 路径 |
|------|------|
| 图片保存 | `{{HOME}}/.openclaw/workspace/inbound_images/` |
| 视频生成 | `{{HOME}}/.openclaw/workspace/openclaw_upload/flash_longxia/` |
| 视频输出 | `{{HOME}}/.openclaw/workspace/openclaw_upload/flash_longxia/output/` |
| 多平台上传 | `{{HOME}}/.openclaw/workspace/openclaw_upload/` |
| Cookies 保存 | `{{HOME}}/.openclaw/workspace/openclaw_upload/cookies/` |
| 登录二维码截图 | `{{HOME}}/.openclaw/workspace/logs/auth_qr/` |

## 两个核心技能

### 1️⃣ 图片生成视频 - flash_longxia (帧龙虾)

```bash
cd {{HOME}}/.openclaw/workspace/openclaw_upload

# 查询可用模型参数（必须先查）
{{PYTHON_CMD}} flash_longxia/zhenlongxia_workflow.py --list-models

# 生成视频（默认参数：auto 模型, 10 秒, 9:16 竖屏）
{{PYTHON_CMD}} flash_longxia/zhenlongxia_workflow.py <图片路径> --model=auto --duration=10 --aspectRatio=9:16 --variants=1 --yes
```

**流程**: 上传图片 → 图生文 → 生成视频任务 → 后台轮询 → 下载 MP4

### 2️⃣ 多平台视频发布

```bash
cd {{HOME}}/.openclaw/workspace/openclaw_upload

# 视频号上传（当前唯一开放平台）
# ⚠️ 标题、文案、标签 必须在发布前根据用户风格 + 人物性格生成！
AUTH_MODE=profile .venv313/bin/python3 platforms/shipinhao_upload/upload.py "<视频路径>" "<标题>" "<文案>" "<标签>"
```

**生成前必读**：
- `IDENTITY.md`：当前助手的人设和 Vibe
- `SOUL.md`：说话风格和边界
- `USER.md`：用户偏好和表达要求
- `flash_longxia/config.yaml`：行业、视频风格、通知配置

**参数说明**：
- `<标题>`: 由 AI 根据用户行业+风格+视频内容+人物性格自动生成（15 字以内）
- `<文案>`: 由 AI 根据视频内容+用户风格+AI 人设自动生成（100-200 字）
- `<标签>`: 由 AI 根据行业+内容生成 3-6 个标签，格式 `#标签1 #标签2 #标签3`

**⚠️ 重要**:
- 标题、文案、标签不能留空
- 不能连续复用同一套开头、结尾或情绪模板
- 如果画面里有人物，文案必须写出人物性格、情绪、关系感或反差点
- 发布前务必先生成，展示给用户确认后再调用上传命令

**⚠️ 当前仅开放视频号**，其他平台（抖音、小红书、快手）暂时关闭。

## Python 环境

- **统一使用 `python3.12`**
- macOS 优先使用：`/opt/homebrew/bin/python3.12`
- Windows 优先使用：`py -3.12`
- 如果项目有 `.venv`，使用 `.venv/bin/python3.12`

## 微信通知配置

- **微信 Target**: `{{WECHAT_TARGET}}`
- **Channel**: `openclaw-weixin`
- **发送命令**: `openclaw message send --channel=openclaw-weixin -t "{{WECHAT_TARGET}}" -m "消息内容" --media=视频路径`

## 飞书通知配置

- **App ID:** `{{FEISHU_APP_ID}}`
- **App Secret:** `{{FEISHU_APP_SECRET}}`

## 用户视频偏好（参考 config.yaml）

> 具体行业和风格在初始化时设定，存储在 `config.yaml` 的 `content` 节：
> - `content.industry` — 用户行业
> - `content.video_style` — 视频风格
>
> 每次发布前，根据这些配置 + 视频内容 **自动生成标题、文案和标签**。
> 详见 `MEMORY.md` 中的「发布内容自动生成规则」。

---

_请根据实际环境修改 {{HOME}} 和 {{PYTHON_CMD}} 占位符_

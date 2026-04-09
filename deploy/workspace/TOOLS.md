# TOOLS.md - 本地配置与操作命令 (Mac/Windows 版)

## Python 版本

**统一使用 Python 3.12**

部署脚本自动安装并配置：
- Mac: `/opt/homebrew/bin/python3.12`（添加到 PATH）
- Windows: `py -3.12`（添加到 PowerShell 别名）

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

## 两个核心技能

### 1️⃣ 图片生成视频 - flash_longxia (帧龙虾)

```bash
# Mac
cd ~/.openclaw/workspace/openclaw_upload
.venv/bin/python flash_longxia/zhenlongxia_workflow.py --list-models
.venv/bin/python flash_longxia/zhenlongxia_workflow.py <图片路径> --yes

# Windows
cd %USERPROFILE%\.openclaw\workspace\openclaw_upload
.venv\Scripts\python.exe flash_longxia\zhenlongxia_workflow.py --list-models
.venv\Scripts\python.exe flash_longxia\zhenlongxia_workflow.py <图片路径> --yes
```

**流程**: 上传图片 → 图生文 → 生成视频任务 → 后台轮询 → 下载 MP4

### 2️⃣ 视频号发布

```bash
# Mac
cd ~/.openclaw/workspace/xiaolong-upload
.venv/bin/python upload.py -p shipinhao "<视频路径>" "<标题>" "<文案>" "<标签>"

# Windows
cd %USERPROFILE%\.openclaw\workspace\xiaolong-upload
.venv\Scripts\python.exe upload.py -p shipinhao "<视频路径>" "<标题>" "<文案>" "<标签>"
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
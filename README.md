# mac-upload

mac-upload 是一个**自动化视频发布系统**，通过 OpenClaw AI 助手实现：发送图片 → AI 生成视频 → 自动发布到视频号 → 微信通知结果。

```
微信发图 → AI 生成视频 → 视频号自动发布 → 微信通知
```

## 目录结构

```text
mac-upload/
├── .github/workflows/      # GitHub Actions 自动同步
├── scripts/               # subtree 同步脚本
├── deploy/                # 一键部署脚本（上游: SunnySLJ/deploy）
├── xiaolong-upload/       # 视频号上传（上游: SunnySLJ/xiaolong-upload）
├── openclaw_upload/       # 图生视频（帧龙虾）
├── install.sh             # macOS 一键安装脚本
├── install.ps1            # Windows 一键安装脚本
├── update.sh / update.bat # 一键更新脚本
└── README.md
```

---

## 快速开始（新 Mac 安装）

### 前置条件

```bash
# 如果没有 Homebrew，先安装
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装必要工具
brew install node git python@3.12
```

### 第一步：运行一键安装

```bash
# 克隆仓库
git clone https://github.com/SunnySLJ/mac-upload.git
cd mac-upload

# 运行安装脚本
chmod +x install.sh
./install.sh
```

安装脚本会交互式询问：
- 选择 LLM 服务商（百炼 / n1n.ai）并输入 API Key
- 设置 AI 助手名称、你的行业、视频风格
- 是否安装飞书插件（可选）
- 视频清理定时任务时间

### 第二步：安装后手动配置

install.sh 在交互过程中会询问的内容（运行脚本时按提示输入即可）：

| 配置项 | install.sh 询问方式 | 说明 |
|--------|-------------------|------|
| **LLM API Key** | 步骤 6 交互输入，选择服务商并填入 Key | 百炼=通义千问 qwen3-coder-plus；n1n.ai=GPT-4.1 + Claude Opus 4.1（默认，选 2）
| 用户信息 | 步骤 7 交互输入 | 你的称呼、行业、视频风格、AI 名字等 |
| 飞书插件 | 步骤 5 可选 | App ID + App Secret |

install.sh 完成后，以下两项需要额外手动操作：

#### 2.1 配置帧龙虾 Token

从帧龙虾平台获取 Token 后写入：

```bash
mkdir -p ~/.openclaw/workspace/openclaw_upload/flash_longxia/
echo "你的帧龙虾Token" > ~/.openclaw/workspace/openclaw_upload/flash_longxia/token.txt
```

#### 2.2 视频号首次登录

首次上传视频前，需要用 Chrome 扫码授权一次（后续自动复用）：

```bash
# 启动 connect Chrome（端口 9226）
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9226 \
  --user-data-dir="$HOME/.openclaw/workspace/openclaw_upload/cookies/chrome_connect_sph"

# 用微信扫码登录视频号
```

登录态保存在本地，后续自动复用。

### 第三步：启动使用

```bash
# 1. 启动 OpenClaw
openclaw

# 2. 绑定微信（如果安装时选择稍后绑定，或当前仍未绑定）
openclaw channels login --channel openclaw-weixin
# 用微信扫码授权

# 3. 发送图片到微信机器人，即可触发：
#    - AI 生成视频（图生视频）
#    - 自动发布到视频号
#    - 微信/飞书通知结果
```

---

## 安装后目录

```
~/.openclaw/
├── openclaw.json               # LLM 配置
├── skills/                    # 4 个 Skills
│   ├── auth/                  # 视频号登录管理
│   ├── flash-longxia/         # 图生视频
│   ├── longxia-upload/        # 视频号发布
│   └── video-cleanup/         # 每周视频清理
├── workspace/
│   ├── xiaolong-upload/       # 视频号上传项目
│   ├── openclaw_upload/        # 图生视频项目
│   ├── flash_longxia/          # 帧龙虾配置
│   │   ├── config.yaml         # AI 生成参数
│   │   └── token.txt           # ⚠️ 需手动配置
│   └── inbound_images/        # 接收图片目录
└── cron/jobs.json             # 定时任务
```

---

## 一键更新

代码更新后，在仓库目录下运行：

```bash
./update.sh
```

这会：
1. 拉取 `mac-upload` 根仓最新代码
2. 同步 `deploy/` 和 `xiaolong-upload/` 上游
3. 刷新 Skills 和 Workspace 配置
4. 重新安装 Python 依赖

---

## 通知渠道

系统支持微信和飞书两种通知方式，可以同时启用：

| 渠道 | 启用方式 | 说明 |
|------|---------|------|
| **微信** | 安装时安装插件 + 扫码授权 | 视频生成完成、发布结果 |
| **飞书** | 安装时选择飞书插件 + 填 App ID/Secret | 同上，可与微信同时启用 |

---

## 定时任务

部署后自动创建以下定时任务：

| 任务 | 频率 | 作用 |
|------|------|------|
| video-cleanup-weekly | 每周二 01:00 | 清理过期视频文件 |

登录状态检查已关闭，登录失效时系统会主动发二维码到微信让你扫码重置。

---

## 常见问题

### Q: 视频号上传失败，提示"请先登录"
A: 登录态过期，需重新扫码。进入 `~/.openclaw/workspace/openclaw_upload/` 启动 connect Chrome 后扫码重置。

### Q: 视频生成失败
A: 检查 `~/.openclaw/workspace/openclaw_upload/flash_longxia/token.txt` 是否配置正确。

### Q: 微信绑定失败
A: 运行 `openclaw channels login --channel openclaw-weixin`，用微信扫码。如提示权限不足，确认微信已开通机器人功能。

### Q: 该选百炼还是 n1n.ai？

install.sh 有两个选项：
- **百炼**（选项 1）— 通义千问 qwen3-coder-plus，代码能力强，适合本地部署
- **n1n.ai**（选项 2，默认）— GPT-4.1 + Claude Opus 4.1，通用推理更强，按量付费

两者 OpenClaw 都能正常驱动，选哪个取决于你的 Key 在哪个平台。

### Q: 想切换 LLM 服务商
A: 直接编辑 `~/.openclaw/openclaw.json`，替换 `apiKey` 和 `ANTHROPIC_AUTH_TOKEN` 字段。

---

## 同步策略

根仓使用 `git subtree` 聚合上游目录：

- `deploy/` ← `https://github.com/SunnySLJ/deploy.git`
- `xiaolong-upload/` ← `https://github.com/SunnySLJ/xiaolong-upload.git`

查看上游状态：

```bash
bash scripts/sync-upstreams.sh status
```

同步全部上游：

```bash
bash scripts/sync-upstreams.sh sync --bootstrap-if-needed
```

---

## Bootstrap 说明

因为当前仓库最初不是按 subtree 初始化的，第一次同步需要 bootstrap。

同步脚本会：

1. 备份当前前缀目录
2. 建立 subtree 元数据
3. 把当前本地定制重新覆盖回去
4. 生成初始化提交

后续同步执行普通的 `git subtree pull --squash`。

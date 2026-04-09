# 🦐 OpenClaw 一键部署包

# deploy

> 虾王智能视频发布系统 — 从零到可用的自动化部署

## 📦 包结构

```
deploy-openclaw/
├── deploy-openclaw.sh          # macOS 部署脚本 (Bash)
├── deploy-openclaw.ps1         # Windows 部署脚本 (PowerShell)
├── README.md                   # 本文件
├── config/
│   ├── openclaw.json.template  # 主配置模板（LLM + 插件 + 通道）
│   └── login_check_config.json # 登录检查配置
├── workspace/                  # Workspace 配置文件模板
│   ├── AGENTS.md               # 会话启动流程
│   ├── IDENTITY.md             # AI 身份（虾王）
│   ├── SOUL.md                 # AI 行为准则
│   ├── USER.md                 # 用户偏好（需自定义）
│   ├── MEMORY.md               # 红线规则 + 经验教训
│   ├── HEARTBEAT.md            # 心跳/定时任务文档
│   └── TOOLS.md                # 工具配置（路径/端口/命令）
└── skills/                     # 技能模板（从当前实例复制）
    ├── flash-longxia/          # 图片生成视频
    ├── auth/                   # 平台登录管理
    ├── longxia-upload/         # 视频发布
    ├── longxia-bootstrap/      # 项目引导
    └── video-cleanup/          # 视频清理
```

## 🚀 快速开始

### macOS

```bash
# 1. 将整个 deploy-openclaw 目录复制到新机器
# 2. 赋予执行权限
chmod +x deploy-openclaw.sh

# 3. 运行一键部署
./deploy-openclaw.sh
```

### Windows

```powershell
# 1. 将整个 deploy-openclaw 目录复制到新机器
# 2. 以管理员身份打开 PowerShell
# 3. 允许脚本执行（如果需要）
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# 4. 运行一键部署
.\deploy-openclaw.ps1
```

## 📋 部署步骤概览（14 步）

| # | 步骤 | 说明 |
|---|------|------|
| 1 | 系统环境检查 | Node.js、npm、Git |
| 2 | Python 3.12 | 检查/安装 |
| 3 | 安装 OpenClaw | 全局安装 CLI |
| 4 | 微信插件 | 安装 WeChat 通道 |
| 5 | 飞书插件（可选） | 安装飞书通道 |
| 6 | 配置 LLM | 交互式输入 API Key |
| 7 | xiaolong-upload | 克隆图生视频项目 |
| 8 | openclaw_upload | 克隆视频发布项目 |
| 9 | Workspace 配置 | 复制 7 个核心 md 文件 |
| 10 | Skills 安装 | 5 个技能安装到位 |
| 11 | Memory 插件 | 向量记忆初始化 |
| 12 | 定时任务 | 登录检查 + 视频清理 |
| 13 | Token + 微信 | 配置推送通道 |
| 14 | 部署验证 | 核对关键文件与脚本 |

## ⚙️ 部署前准备

### 必须准备

- [ ] **百炼 API Key** (`sk-sp-xxx`) — 用于 LLM 和 Embedding
- [ ] **Node.js v18+** — [下载](https://nodejs.org/)
- [ ] **Git** — [下载](https://git-scm.com/)

### 可选准备

- [ ] **视频生成 API Token** — 帧龙虾服务的认证 Token
- [ ] **飞书 App ID + Secret** — 如果使用飞书通道
- [ ] **微信 Target ID** — 接收通知的微信 ID

## 🔧 部署后操作

1. **启动 OpenClaw**: `openclaw`
2. **绑定微信**: `openclaw channel connect openclaw-weixin` → 扫码
3. **初始化虾王**: 对虾王说"你好，帮我初始化环境"
4. **安装技能**: 告诉虾王"帮我安装 xiaolong-upload 和 openclaw_upload"
5. **自定义偏好**: 修改 `~/.openclaw/workspace/USER.md`

## 🔄 更新技能代码

部署后可随时拉取最新代码：

```bash
# macOS
~/.openclaw/workspace/update-skills.sh

# 或手动
cd ~/.openclaw/workspace/xiaolong-upload && git pull
cd ~/.openclaw/workspace/openclaw_upload && git pull
```

## ⚠️ 注意事项

1. **微信授权需要扫码** — 脚本无法自动完成，部署后需手动扫码
2. **API Key 安全** — 模板中使用占位符，部署时交互式输入，不硬编码
3. **Python 版本** — 必须使用 3.12，不兼容低版本
4. **首次运行** — OpenClaw 首次启动会自动初始化向量数据库，可能需要几分钟

## 📝 两种部署模式

- **全新部署（模式 1）** — 从零开始，安装所有组件
- **迁移部署（模式 2）** — OpenClaw 已安装，仅配置技能和文件

---

_🦐 虾王 OpenClaw 一键部署包 v1.0.0_

## Docker 镜像方案

这个仓库现在也可以直接构建成可分发的 Docker 镜像，镜像内会预装：

- `openclaw@latest`
- `xiaolong-upload`
- `openclaw_upload`
- 本仓库 `skills/` 里的内置 skills
- 从这两个项目仓库同步出来的 skills

### 构建镜像

```bash
docker build -t openclaw-bundled:latest .
```

### 运行镜像

```bash
docker run -it --name openclaw \
  -e OPENCLAW_PROVIDER=n1n \
  -e OPENCLAW_API_KEY=sk-xxx \
  -v openclaw-data:/root/.openclaw \
  openclaw-bundled:latest
```

建议挂载 `/root/.openclaw`，这样别人更新仓库或补充配置后，容器重建也不会丢数据。

### 使用 docker compose

仓库已经附带 [docker-compose.yml](/C:/Users/爽爽/Desktop/deploy/docker-compose.yml)，最小启动方式：

```bash
export OPENCLAW_API_KEY=sk-xxx
docker compose up -d --build
```

首次启动时，如果卷里还没有 `openclaw.json`，入口脚本会自动按环境变量生成：

- `OPENCLAW_PROVIDER=n1n` 或 `bailian`
- `OPENCLAW_API_KEY`

如果没有传 `OPENCLAW_API_KEY`，会生成带占位符的配置文件，之后再进容器或挂载卷手动修改也可以。

### 容器内更新两个项目仓库

镜像内置了更新命令：

```bash
openclaw-update-bundled-repos
```

这个命令会：

- 更新 `xiaolong-upload`
- 更新 `openclaw_upload`
- 重新安装两个仓库需要的依赖
- 重新把它们对应的 skills 同步到 `~/.openclaw/skills`

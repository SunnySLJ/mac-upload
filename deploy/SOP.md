# OpenClaw 一键部署 SOP

> 适用版本：`deploy-openclaw.sh` / `deploy-openclaw.ps1` 当前仓库版本
>
> 文档更新时间：2026-04-03
>
> 固定 OpenClaw 版本：`2026.3.28`

这份文档是部署脚本的说明书，不是概念介绍。目标只有一个：让你按脚本的真实行为完成部署、验证和迁移，不踩文档和脚本不一致的坑。

---

## 1. 先看这三件事

### 1.1 这份 SOP 适合谁

- 第一次在新机器上部署 OpenClaw
- 已有 OpenClaw，想把视频生成/上传能力补齐
- 想把旧机器配置迁移到新机器

### 1.2 脚本最终会落地什么

部署完成后，机器上会新增或更新这些内容：

- `~/.openclaw/openclaw.json`
- `~/.openclaw/workspace/` 下的核心工作区文件
- `~/.openclaw/workspace/xiaolong-upload`
- `~/.openclaw/workspace/openclaw_upload`
- `~/.openclaw/skills/` 下的 5 个技能
- `~/.openclaw/cron/jobs.json`
- 可选的记忆/上下文插件代码

### 1.3 两种部署模式的区别

| 模式 | 适用场景 | 会执行什么 | 不会执行什么 |
|------|----------|------------|--------------|
| 全新部署（1） | 新机器，从零开始 | 14 步完整执行 | 无 |
| 迁移部署（2） | 机器上已有 OpenClaw | 仍会检查系统、Python、配置、项目、技能、定时任务 | 跳过步骤 3「安装 OpenClaw」和步骤 4「安装微信插件」 |

> 注意：迁移部署依然会进入步骤 7，如果检测到已有 `openclaw.json`，脚本会询问你是否覆盖。

---

## 2. 部署前准备

### 2.1 系统和软件要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 12+ 或 Windows 10/11 |
| Node.js | 18+ |
| npm / npx | 随 Node.js 可用 |
| Git | 已安装 |
| Python | 3.12.x |
| 网络 | 能访问 GitHub、npm、OpenClaw 插件依赖和相关 API |

推荐最低配置：

- 内存 `8GB+`，推荐 `16GB`
- 可用磁盘 `2GB+`

### 2.2 部署前要准备的账号和参数

| 项目 | 是否必须 | 用途 |
|------|----------|------|
| LLM API Key | 是 | 生成 `openclaw.json` |
| 视频生成 Token | 否 | 帧龙虾图生视频 |
| 微信 Target ID | 否 | 完成后通知推送 |
| 飞书 App ID / Secret | 否 | 飞书通知 |

### 2.3 部署时会问你的偏好

脚本会交互式收集这些信息，并写入工作区文件：

- 你希望 AI 如何称呼你
- 你的行业
- 你的视频风格
- AI 助手名称
- AI 表情和性格
- 发布前是否需要人工确认
- SOUL 风格模板
- 每日登录检查时间
- 每周视频清理时间

---

## 3. 快速部署

### 3.1 macOS

```bash
cd deploy-openclaw
chmod +x deploy-openclaw.sh
./deploy-openclaw.sh
```

### 3.2 Windows

```powershell
cd deploy-openclaw
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
.\deploy-openclaw.ps1
```

### 3.3 部署完成后第一时间执行

```bash
openclaw
```

然后绑定微信：

```bash
openclaw channel connect openclaw-weixin
```

---

## 4. 14 步部署流程说明

这一节按脚本真实顺序说明每一步做什么、你需要输入什么、会生成什么。

### 步骤 1：检查系统环境

脚本会检查：

- 操作系统
- `node`
- `npm`
- `npx`
- `git`
- macOS 下的 `brew`

如果缺少必要组件，脚本会直接退出，不会继续部署。

### 步骤 2：检查 Python 3.12

脚本只接受 Python `3.12.x`。

- macOS：优先查找 `/opt/homebrew/bin/python3.12`、`/usr/local/bin/python3.12`、`python3.12`
- Windows：优先查找 `py -3.12`、`python3.12`、`python`

macOS 下如果没找到且已安装 Homebrew，脚本会询问是否执行：

```bash
brew install python@3.12
```

### 步骤 3：安装 OpenClaw

仅全新部署执行。

脚本会安装固定版本：

```bash
npm install -g openclaw@2026.3.28
```

同时创建目录：

```text
~/.openclaw/
~/.openclaw/workspace/
~/.openclaw/skills/
~/.openclaw/workspace/inbound_images/
~/.openclaw/workspace/inbound_videos/
~/.openclaw/workspace/logs/auth_qr/
~/.openclaw/workspace/memory/
```

### 步骤 4：安装微信插件

仅全新部署执行。

脚本会运行：

```bash
npx -y @tencent-weixin/openclaw-weixin-cli@latest install
```

这一步只是安装插件，不会自动完成扫码绑定。真正绑定仍要在部署后执行：

```bash
openclaw channel connect openclaw-weixin
```

### 步骤 5：安装飞书插件（可选）

你会被问到是否安装飞书插件。

如果选择安装并填写 `App ID / App Secret`，脚本会生成：

```text
~/.openclaw/credentials/feishu-main-allowFrom.json
```

同时把飞书通知配置写入后续生成的 `flash_longxia/config.yaml`。

### 步骤 6：用户个性化初始化

这一步会生成部署用的用户信息和 AI 设定，后面会写入：

- `IDENTITY.md`
- `SOUL.md`
- `USER.md`
- `flash_longxia/config.yaml`

这里最关键的两个选项：

- `发布前是否人工确认`
- `SOUL 风格模板`

前者会影响视频生成前是否要求确认，后者会决定工作区里的默认行为风格。

### 步骤 7：配置 LLM

你需要二选一：

| 方案 | 默认模型 | 模板文件 |
|------|----------|----------|
| 百炼 | `qwen3-coder-plus` | `config/openclaw-bailian.json.template` |
| n1n.ai | `gpt-4.1` | `config/openclaw-n1n.json.template` |

脚本会把你填写的 API Key 写入：

```text
~/.openclaw/openclaw.json
```

同时会把 `memory-lancedb-pro` 和 `lossless-claw` 的配置一并对齐到同一服务商。

如果已有 `~/.openclaw/openclaw.json`，脚本会先询问是否覆盖。

### 步骤 8：安装 `xiaolong-upload`

脚本会把项目克隆或更新到：

```text
~/.openclaw/workspace/xiaolong-upload
```

然后自动处理依赖：

- 如果存在 `requirements.txt`，创建 `.venv` 并安装 Python 依赖
- 如果存在 `package.json`，执行 `npm install`

随后会额外询问你，是否把这个项目里的技能同步到 OpenClaw：

- `auth`
- `longxia-bootstrap`
- `longxia-upload`

### 步骤 9：安装 `openclaw_upload`

脚本会把项目克隆或更新到：

```text
~/.openclaw/workspace/openclaw_upload
```

并自动创建这些目录：

```text
cookies/
logs/
published/
flash_longxia/output/
scripts/
```

随后会把仓库内置的视频清理脚本复制到：

```text
~/.openclaw/workspace/openclaw_upload/scripts/cleanup_uploaded_videos.py
```

这一步还会生成：

```text
~/.openclaw/workspace/openclaw_upload/flash_longxia/config.yaml
```

其中会自动写入：

- `content.industry`
- `content.video_style`
- `video.confirm_before_generate`
- 微信通知结构
- 飞书通知结构（若步骤 5 已配置）

最后会询问是否把 `flash-longxia` 技能同步到 OpenClaw。

### 步骤 10：初始化 Workspace 配置文件

脚本会在 `~/.openclaw/workspace/` 下生成或复制这些文件：

| 文件 | 生成方式 |
|------|----------|
| `IDENTITY.md` | 根据步骤 6 输入生成 |
| `SOUL.md` | 根据步骤 6 所选模板生成 |
| `USER.md` | 根据步骤 6 输入生成 |
| `AGENTS.md` | 从 `workspace/` 模板复制并替换路径 |
| `MEMORY.md` | 从 `workspace/` 模板复制并替换路径 |
| `HEARTBEAT.md` | 从 `workspace/` 模板复制并替换路径 |
| `TOOLS.md` | 从 `workspace/` 模板复制并替换路径 |

默认策略是：

- 已存在的文件不覆盖
- 新文件按当前机器路径和 Python 命令自动替换占位符

### 步骤 11：安装本地 Skills

脚本会从当前部署包的 `skills/` 目录补齐技能到：

```text
~/.openclaw/skills/
```

默认包含 5 个技能：

- `flash-longxia`
- `auth`
- `longxia-upload`
- `longxia-bootstrap`
- `video-cleanup`

另外，脚本会自动更新：

```text
~/.openclaw/skills/longxia-bootstrap/project_config.json
```

其中会写入：

- `project_root`
- `project_root_candidates`
- `python_cmd`

> 即使你在步骤 8 和步骤 9 里选择了安装技能，步骤 11 仍会执行一次“补齐”。已存在的技能不会被覆盖。

### 步骤 12：安装 Memory / Context 插件

这一步不是“等首次启动自动安装”，而是脚本直接询问并执行 Git 克隆与依赖安装。

可选插件有两个：

- `memory-lancedb-pro`
- `lossless-claw-enhanced`

默认安装位置：

```text
~/.openclaw/workspace/plugins/memory-lancedb-pro
~/.openclaw/workspace/plugins/lossless-claw-enhanced
```

脚本完成后会同步更新 `openclaw.json` 的插件配置。

### 步骤 13：创建定时任务

脚本会生成：

```text
~/.openclaw/cron/jobs.json
```

包含两个 Cron 任务：

| 任务 | 默认时间 | 实际执行内容 |
|------|----------|--------------|
| 登录状态检查 | 每天 `10:10` | 运行 `xiaolong-upload/skills/auth/scripts/scheduled_login_check.py` |
| 视频清理 | 每周二 `01:00` | 运行 `openclaw_upload/scripts/cleanup_uploaded_videos.py` |

同时会生成：

```text
~/.openclaw/skills/auth/login_check_config.json
```

### 步骤 14：配置 Token 和微信推送

这一步会询问两个值：

- 视频生成 Token
- 微信 Target ID

写入位置如下：

| 内容 | 路径 |
|------|------|
| 视频生成 Token | `~/.openclaw/workspace/openclaw_upload/flash_longxia/token.txt` |
| 微信 Target ID | `~/.openclaw/workspace/openclaw_upload/flash_longxia/config.yaml` |

如果这一步先留空，后面也可以手动补。

---

## 5. 部署后必须做的事

### 5.1 启动 OpenClaw

```bash
openclaw
```

### 5.2 绑定微信

```bash
openclaw channel connect openclaw-weixin
```

绑定成功后，如果你在步骤 14 没填 `wechat_target`，需要把实际 Target ID 手动补到：

```text
~/.openclaw/workspace/openclaw_upload/flash_longxia/config.yaml
```

### 5.3 做一次最小闭环验证

建议按这个顺序：

1. 确认 `openclaw` 能正常启动
2. 确认微信已绑定
3. 准备 1 张测试图片
4. 触发一次图生视频
5. 确认生成完成后通知正常
6. 走一次上传流程，检查标题、文案、标签和发布确认逻辑

### 5.4 更新项目代码

脚本会自动生成更新脚本：

```bash
~/.openclaw/workspace/update-skills.sh
```

用于同步：

- `xiaolong-upload`
- `openclaw_upload`

---

## 6. 验证清单

### 6.1 关键文件

- [ ] `~/.openclaw/openclaw.json`
- [ ] `~/.openclaw/workspace/IDENTITY.md`
- [ ] `~/.openclaw/workspace/SOUL.md`
- [ ] `~/.openclaw/workspace/USER.md`
- [ ] `~/.openclaw/workspace/MEMORY.md`
- [ ] `~/.openclaw/workspace/TOOLS.md`
- [ ] `~/.openclaw/cron/jobs.json`
- [ ] `~/.openclaw/workspace/openclaw_upload/flash_longxia/config.yaml`
- [ ] `~/.openclaw/workspace/openclaw_upload/scripts/cleanup_uploaded_videos.py`

### 6.2 项目目录

- [ ] `~/.openclaw/workspace/xiaolong-upload`
- [ ] `~/.openclaw/workspace/openclaw_upload`
- [ ] `~/.openclaw/workspace/plugins/memory-lancedb-pro`（如选择安装）
- [ ] `~/.openclaw/workspace/plugins/lossless-claw-enhanced`（如选择安装）

### 6.3 技能目录

- [ ] `~/.openclaw/skills/flash-longxia`
- [ ] `~/.openclaw/skills/auth`
- [ ] `~/.openclaw/skills/longxia-upload`
- [ ] `~/.openclaw/skills/longxia-bootstrap`
- [ ] `~/.openclaw/skills/video-cleanup`

### 6.4 功能验证

- [ ] `openclaw --version` 正常输出
- [ ] 微信扫码绑定成功
- [ ] 图生视频能成功创建任务
- [ ] 生成完成后通知正常
- [ ] 上传流程能读取登录状态
- [ ] 发布确认逻辑符合你的选择
- [ ] 定时任务时间正确

---

## 7. 迁移部署

迁移部署建议使用模式 `2`，但迁移前要先明确一点：

- 模式 `2` 不是“只复制文件”
- 它仍然会检查环境、重建工作区、重新配置 LLM、重新拉项目、重新生成 Cron

所以迁移的正确做法是：先备份，再跑模式 `2`，最后恢复你真正需要保留的状态文件。

### 7.1 建议备份的内容

| 类型 | 路径 |
|------|------|
| 主配置 | `~/.openclaw/openclaw.json` |
| 工作记忆 | `~/.openclaw/workspace/MEMORY.md` |
| 定时任务 | `~/.openclaw/cron/jobs.json` |
| 视频 Token | `~/.openclaw/workspace/openclaw_upload/flash_longxia/token.txt` |
| 平台登录态 | `~/.openclaw/workspace/openclaw_upload/cookies/` |
| 向量记忆 | `~/.openclaw/memory/` |

### 7.2 建议迁移顺序

1. 在旧机器备份关键文件和目录
2. 把 `deploy-openclaw/` 复制到新机器
3. 在新机器执行部署脚本并选择模式 `2`
4. 视情况恢复 `MEMORY.md`、`token.txt`、`cookies/`、向量记忆目录
5. 启动 OpenClaw 并重新做一次最小闭环验证

### 7.3 一个可用的备份示例

```bash
tar -czf openclaw-backup.tar.gz \
  ~/.openclaw/openclaw.json \
  ~/.openclaw/workspace/MEMORY.md \
  ~/.openclaw/cron/jobs.json \
  ~/.openclaw/workspace/openclaw_upload/flash_longxia/token.txt \
  ~/.openclaw/workspace/openclaw_upload/cookies
```

---

## 8. 常见问题

### 8.1 缺少 Node.js / npm / npx

macOS：

```bash
brew install node
```

Windows：

- 从 `nodejs.org` 安装最新版 LTS

### 8.2 找不到 Python 3.12

macOS：

```bash
brew install python@3.12
```

Windows：

- 从 `python.org` 安装 `3.12.x`
- 安装时勾选 `Add to PATH`
- 建议同时勾选 `py launcher`

### 8.3 迁移部署后把旧配置覆盖掉了

原因通常是步骤 7 里选择了覆盖 `openclaw.json`。

处理方式：

- 用你备份的 `openclaw.json` 恢复
- 或重新运行部署脚本，在覆盖提示处选择 `N`

### 8.4 微信已绑定，但通知收不到

重点检查：

- `openclaw channel connect openclaw-weixin` 是否真的绑定成功
- `config.yaml` 中 `wechat_target` 是否为空
- 你填入的 Target ID 是否是实际可用的 `xxx@im.wechat`

### 8.5 定时任务没有按时执行

先检查：

```bash
cat ~/.openclaw/cron/jobs.json
```

确认：

- `enabled` 为 `true`
- `expr` 是你期望的时间
- `tz` 为 `Asia/Shanghai`

### 8.6 记忆插件安装失败

这一步依赖 GitHub 和 npm 网络可用。

优先检查：

- 是否能访问 GitHub
- 是否能执行 `npm install`
- `~/.openclaw/workspace/plugins/` 下是否已有半成品目录

### 8.7 视频生成 Token 失效

直接更新：

```bash
echo '新Token' > ~/.openclaw/workspace/openclaw_upload/flash_longxia/token.txt
```

---

## 9. 部署完成后的目录参考

```text
~/.openclaw/
├── openclaw.json
├── cron/
│   └── jobs.json
├── credentials/
│   └── feishu-main-allowFrom.json
├── skills/
│   ├── auth/
│   ├── flash-longxia/
│   ├── longxia-bootstrap/
│   ├── longxia-upload/
│   └── video-cleanup/
└── workspace/
    ├── AGENTS.md
    ├── HEARTBEAT.md
    ├── IDENTITY.md
    ├── MEMORY.md
    ├── SOUL.md
    ├── TOOLS.md
    ├── USER.md
    ├── plugins/
    ├── xiaolong-upload/
    └── openclaw_upload/
```

---

如果后续你修改了 `deploy-openclaw.sh`、`deploy-openclaw.ps1`、`config/`、`workspace/` 或 `skills/` 的行为，这份 SOP 也需要一起更新。文档必须跟脚本行为一致，不能只改其中一边。

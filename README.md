# mac-openclaw

> 虾王智能视频发布系统 — Mac / Windows 双平台版

一键部署 OpenClaw + 视频号上传 + 帧龙虾图生视频。

## 项目结构

```text
mac-openclaw/
├── install.sh              # Mac 一键部署脚本
├── install.ps1             # Windows 一键部署脚本 (PowerShell)
├── update.sh               # Mac 快速更新脚本
├── update.bat              # Windows 快速更新脚本
├── deploy/                 # 完整部署配置（交互式）
├── xiaolong-upload/        # 视频号上传项目
│   ├── common/
│   ├── platforms/
│   │   ├── shipinhao_upload/   # 视频号（当前开放）
│   │   ├── douyin_upload/      # 抖音（历史实现）
│   │   ├── ks_upload/          # 快手（历史实现）
│   │   └── xhs_upload/         # 小红书（历史实现）
│   └── upload.py
└── openclaw_upload/        # 帧龙虾图生视频
    └── flash_longxia/
```

## Python 版本

**统一使用 Python 3.12**

部署脚本会自动：
- 检测并安装 Python 3.12
- 配置 Python 3.12 为默认版本
- 创建虚拟环境

## 快速开始

### macOS

```bash
# 1. 进入项目目录
cd mac-openclaw

# 2. 赋予执行权限
chmod +x install.sh update.sh

# 3. 一键部署（自动安装 Python 3.12）
./install.sh

# 4. 重启终端使 Python 配置生效
```

### Windows

```powershell
# 1. 进入项目目录
cd mac-openclaw

# 2. 一键部署
.\install.ps1

# 3. 重启 PowerShell 使配置生效
```

**PowerShell 执行策略**（如果报错）：
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## 智能模式

脚本会自动检测安装状态：

| 状态 | 行为 |
|------|------|
| 全新环境 | 安装 Python 3.12 + OpenClaw + 项目 + Skills |
| 已安装 OpenClaw | 补充安装项目 |
| 已全部安装 | 提示更新选项 |

## 快速更新

已安装环境，一键更新：

```bash
# Mac
./update.sh

# Windows
.\update.bat
```

## 部署后目录

```
~/.openclaw/                    # Mac
%USERPROFILE%\.openclaw\        # Windows
├── openclaw.json
├── workspace/
│   ├── xiaolong-upload/
│   ├── openclaw_upload/
│   ├── update-all.sh/bat       # 更新脚本
│   └── *.md                    # 配置文件
└── skills/
```

## 部署前准备

### Mac
- [ ] Node.js v18+ — `brew install node`
- [ ] Git — `brew install git`
- [ ] Homebrew — https://brew.sh

### Windows
- [ ] Node.js v18+ — https://nodejs.org/
- [ ] Git — https://git-scm.com/

> Python 3.12 由部署脚本自动安装

## 部署后操作

```bash
# 1. 重启终端（使 Python 3.12 配置生效）

# 2. 启动 OpenClaw
openclaw

# 3. 绑定微信
openclaw channel connect openclaw-weixin

# 4. 扫码授权
```

## 使用示例

### 视频号上传

```bash
# Mac
cd ~/.openclaw/workspace/xiaolong-upload
.venv/bin/python upload.py -p shipinhao video.mp4 "标题" "文案" "标签"

# Windows
cd %USERPROFILE%\.openclaw\workspace\xiaolong-upload
.venv\Scripts\python.exe upload.py -p shipinhao video.mp4 "标题" "文案" "标签"
```

### 帧龙虾图生视频

```bash
# Mac
cd ~/.openclaw/workspace/openclaw_upload
.venv/bin/python flash_longxia/zhenlongxia_workflow.py image.jpg --yes

# Windows
cd %USERPROFILE%\.openclaw\workspace\openclaw_upload
.venv\Scripts\python.exe flash_longxia\zhenlongxia_workflow.py image.jpg --yes
```

## 注意事项

1. **统一 Python 3.12** — 部署脚本自动安装配置
2. **登录态需要重新扫码** — cookies 目录不迁移
3. **Mac 辅助功能权限** — 系统偏好设置 → 隐私 → 辅助功能
4. **不要复制 .venv** — 在新机器上重新创建
5. **微信授权** — 需要扫码完成绑定

## 脚本说明

| 脚本 | 平台 | 功能 |
|------|------|------|
| `install.sh` | Mac | 一键部署/更新（自动安装 Python 3.12） |
| `install.ps1` | Windows | 一键部署/更新（自动安装 Python 3.12） |
| `update.sh` | Mac | 快速更新代码 |
| `update.bat` | Windows | 快速更新代码 |

---

_🦐 虾王 OpenClaw Mac/Windows 版 v1.1.0_
---
name: repo-sync
description: 仓库同步技能。当用户提到“拉最新代码”“同步仓库”“git pull 更新”“从远端更新 skill/脚本/配置”“先检查仓库状态再更新”时使用。负责检查本地 git 仓库状态、确认远端与分支、在安全前提下执行 fetch/pull，并回传更新结果与失败原因。
---

# Repo Sync

本技能用于把“仓库里的最新代码”接到实际执行流程里，避免 skill 永远停留在一份静态说明。

## 适用场景

- 更新当前仓库到远端最新版本
- 先检查本地是否有未提交改动，再决定是否允许同步
- 给 skill、脚本、模板这类本地资源接上 git 仓库更新能力
- 在执行发布、部署、登录、清理前，先同步依赖仓库

## 强制约束

1. 默认只允许在工作区干净时执行同步。
2. 若检测到未提交改动，必须明确提示并停止，不能自动覆盖。
3. 默认使用 `git pull --ff-only`，避免静默制造 merge commit。
4. 若用户没有指定仓库路径，优先使用 skill 配置里的默认仓库；若仍为空，再使用当前工作目录。
5. 若目标目录不是 git 仓库，必须直接报错并停止。

## 可执行脚本

脚本路径：

```bash
python3 skills/repo-sync/scripts/repo_sync.py
```

常用命令：

查看默认配置：

```bash
python3 skills/repo-sync/scripts/repo_sync.py show-config
```

设置默认仓库：

```bash
python3 skills/repo-sync/scripts/repo_sync.py set-repo /abs/path/to/repo --remote origin --branch main
```

检查仓库状态：

```bash
python3 skills/repo-sync/scripts/repo_sync.py status
python3 skills/repo-sync/scripts/repo_sync.py status --repo /abs/path/to/repo
```

同步最新代码：

```bash
python3 skills/repo-sync/scripts/repo_sync.py sync
python3 skills/repo-sync/scripts/repo_sync.py sync --repo /abs/path/to/repo --remote origin --branch main
```

若用户明确允许带本地改动继续拉取：

```bash
python3 skills/repo-sync/scripts/repo_sync.py sync --repo /abs/path/to/repo --allow-dirty
```

## 推荐流程

1. 先跑 `status`
2. 确认当前分支、upstream、ahead/behind、是否有未提交改动
3. 若工作区干净，执行 `sync`
4. 将本次是否更新、更新了多少提交、失败原因明确回传给用户

## 设计边界

- 本 skill 只负责 git 仓库状态检查和同步
- 不自动安装依赖、不自动运行测试、不自动发布
- 若用户需要“拉完代码后继续部署/发布”，同步完成后再交给其他 skill 或项目脚本处理

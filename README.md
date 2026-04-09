# mac-openclaw

`mac-upload` 现在作为唯一入口仓。

这个仓库聚合并管理：

- `deploy/`
- `xiaolong-upload/`
- `openclaw_upload/`

其中：

- `deploy/` 的上游是 `https://github.com/SunnySLJ/deploy.git`
- `xiaolong-upload/` 的上游是 `https://github.com/SunnySLJ/xiaolong-upload.git`
- `mac-upload` 自己负责把这些目录作为统一分发入口组织起来

## 目录结构

```text
mac-openclaw/
├── .github/workflows/
├── docs/
├── scripts/
│   ├── sync-upstreams.sh
│   └── sync-upstreams.ps1
├── deploy/
├── xiaolong-upload/
├── openclaw_upload/
├── install.sh
├── install.ps1
├── update.sh
└── update.bat
```

## 同步策略

根仓使用 `git subtree` 聚合上游目录。

目标是：

1. 平时只更新 `mac-upload`。
2. `deploy/` 和 `xiaolong-upload/` 通过 subtree 从各自上游同步。
3. GitHub Actions 定时把上游更新自动同步回 `mac-upload`。

## 本地命令

查看上游状态：

```bash
bash scripts/sync-upstreams.sh status
```

同步全部上游：

```bash
bash scripts/sync-upstreams.sh sync --bootstrap-if-needed
```

只同步一个上游：

```bash
bash scripts/sync-upstreams.sh sync --bootstrap-if-needed --name deploy
bash scripts/sync-upstreams.sh sync --bootstrap-if-needed --name xiaolong-upload
```

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-upstreams.ps1 -Action sync -BootstrapIfNeeded
```

## 一键更新

Mac：

```bash
./update.sh
```

Windows：

```bat
update.bat
```

这两个脚本会：

1. 先更新 `mac-upload` 根仓。
2. 再同步 `deploy` 和 `xiaolong-upload` 上游。
3. 最后刷新本地子项目依赖（如果 `.venv` 已存在）。

## 自动同步

仓库包含 workflow：

- `.github/workflows/sync-upstreams.yml`

它会：

- 定时运行
- 手动触发运行
- 调用同一套 subtree 同步脚本
- 如果有变化，直接推送回 `main`

如果仓库启用了禁止 Actions 直推 `main` 的 branch protection，需要把 workflow 改成“推送同步分支 + 提 PR”。

## Bootstrap 说明

因为当前仓库最初不是按 subtree 初始化的，所以第一次同步需要 bootstrap。

同步脚本会：

1. 备份当前前缀目录。
2. 建立 subtree 元数据。
3. 把当前本地定制重新覆盖回去。
4. 生成初始化提交。

后续再同步时，就只会执行普通的 `git subtree pull --squash`。

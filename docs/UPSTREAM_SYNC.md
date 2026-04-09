# Upstream Sync

`mac-upload` 是聚合入口仓。

当前聚合两个独立上游：

- `deploy` -> `deploy/`
- `xiaolong-upload` -> `xiaolong-upload/`

## 为什么用 subtree

- 目录仍然是普通目录，不需要 submodule 初始化。
- 根仓可以直接携带聚合后的代码快照。
- 上游更新可以被同步进当前仓库，同时保留当前仓库的自定义修改。

## 命令

查看状态：

```bash
bash scripts/sync-upstreams.sh status
```

同步全部：

```bash
bash scripts/sync-upstreams.sh sync --bootstrap-if-needed
```

只同步一个：

```bash
bash scripts/sync-upstreams.sh sync --bootstrap-if-needed --name deploy
bash scripts/sync-upstreams.sh sync --bootstrap-if-needed --name xiaolong-upload
```

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-upstreams.ps1 -Action sync -BootstrapIfNeeded
```

## 第一次同步

第一次同步会自动 bootstrap：

1. 备份当前目录。
2. 建立 subtree 元数据。
3. 重新覆盖当前仓库已有定制。
4. 形成初始化提交。

## 自动同步

GitHub Actions workflow 位于：

- `.github/workflows/sync-upstreams.yml`

默认行为：

- 定时同步
- 支持手动触发
- 如果有变化，直接推送回 `main`

如果你的仓库开启了 branch protection，不允许 Actions 直推 `main`，需要把 workflow 调整为推送同步分支后提 PR。

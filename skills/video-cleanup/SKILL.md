---
name: video-cleanup
description: 自动清理已生成或已上传的视频文件，支持手动执行和定时任务。用于检查 flash_longxia/output 下的视频积压、调整保留天数、试运行清理或排查清理脚本问题。
---

# video-cleanup

使用此 skill 时，优先复用项目里的 `scripts/cleanup_uploaded_videos.py`，不要重写清理逻辑。

## 定位目录

- 优先在 `~/.openclaw/workspace/openclaw_upload` 下执行。
- 如果工作区不在默认位置，显式传入 `--workspace-root` 和 `--project-root`。
- 默认读取 `~/.openclaw/skills/flash-longxia/cleanup_config.json` 中的清理配置。

## 常用命令

```bash
cd ~/.openclaw/workspace/openclaw_upload

python3 scripts/cleanup_uploaded_videos.py
python3 scripts/cleanup_uploaded_videos.py --dry-run
python3 scripts/cleanup_uploaded_videos.py --keep-days 3
python3 scripts/cleanup_uploaded_videos.py --delete-method delete
```

## 执行规则

- 默认只清理 `flash_longxia/output/` 下的 `.mp4` 文件。
- 默认保留最近 7 天的视频。
- 默认优先移动到回收站；只有用户明确要求时才使用永久删除。
- 如果输出目录不存在，应直接报告并结束，不要报假成功。
- 调整保留策略时，同步检查 `skills/flash-longxia/cleanup_config.json` 是否需要更新。

## 排错

- 如果没有任何文件被清理，先确认文件修改时间是否早于保留天数。
- 如果提示找不到输出目录，先检查 `openclaw_upload` 根目录和 `output_dir` 配置。
- 如果定时任务未执行，检查 `~/.openclaw/cron/jobs.json` 中的 `video-cleanup-weekly` 配置。

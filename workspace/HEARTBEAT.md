# HEARTBEAT.md - 定时任务配置

## 每日定时任务

### 登录状态检查

- **时间**: 每天 10:10（可配置）
- **配置文件**: `xiaolong-upload/skills/auth/login_check_config.json`
- **任务**: 检查平台登录状态（当前仅视频号）
- **执行**: 若登录失效，自动尝试恢复会话；如失败则发送微信通知

### 视频输出目录清理

- **时间**: 每周二凌晨 01:00（可配置）
- **任务**: 清理 `flash_longxia/output/` 目录
- **规则**: 保留最近 7 天的视频文件

## 心跳检查项（每次心跳轮询 2-4 项）

- [ ] 检查平台登录状态（轮换检查）
- [ ] 检查是否有待处理的视频生成任务
- [ ] 检查通知队列

## 心跳状态追踪

记录在 `memory/heartbeat-state.json`：

```json
{
  "lastChecks": {
    "login_status": null,
    "video_tasks": null,
    "video_notifications": null
  },
  "lastOutreach": null
}
```

---

_部署时自动生成，可根据需要调整检查时间_

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
.venv/bin/python flash_longxia/zhenlongxia_workflow.py <图片路径>

# Windows
cd %USERPROFILE%\.openclaw\workspace\openclaw_upload
.venv\Scripts\python.exe flash_longxia\zhenlongxia_workflow.py --list-models
.venv\Scripts\python.exe flash_longxia\zhenlongxia_workflow.py <图片路径>
```

**流程**: 上传图片 → 询问是否需要行业模板 → 如需要则查询并展示模板 → 图生文 → 生成视频任务 → 后台轮询 → 下载 MP4

**行业模板规则**：
- 默认不要传递行业模板参数。
- 严禁直接裸请求 `api/v1/aiTemplate/pageList` / `api/v1/aiTemplateCategory/getList`。若未带正确 `token`、POST 请求体和参数，接口常会返回 `code=1003, msg=服务器开小差了，请稍后再试`，这是错误调用，不是模板服务真实故障。
- 图片上传完成后，先问用户这次是否需要行业模板。
- 如果用户说需要，先取行业分类列表；首轮不传 `tabType`。
- 用户选定分类后，再用该 `tabType` 和 `menuType=1` 查询对应模板列表。
- 再把候选模板的 `id/title` 返回给用户选择。
- 用户选定模板后，再把 `tmpplateId` 和模板 `title` 传给 `generateVideo`。
- 如果用户跳过模板，则继续生成，但请求体里不要带 `tmpplateId` / `templateId`。
- 只有用户明确要求无人值守时，才使用 `--yes` 跳过交互确认。

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

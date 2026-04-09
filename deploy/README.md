# OpenClaw 部署包

用于在 Mac 上部署 OpenClaw 工作区，当前包含：

- 视频号上传项目 `xiaolong-upload`
- 图生视频项目 `openclaw_upload`
- 配套 workspace 配置与 skills

## 目录

```text
deploy/
├── deploy-openclaw.sh
├── workspace/
├── skills/
└── README.md
```

## 部署步骤概览

| # | 步骤 | 说明 |
|---|---|---|
| 1 | 环境检查 | Node.js、npm、Git |
| 2 | Python 3.12 | 检查或安装 |
| 3 | 安装 OpenClaw | 全局 CLI |
| 4 | 微信插件 | 安装 WeChat 通道 |
| 5 | 飞书插件 | 可选 |
| 6 | 配置 LLM | 交互式输入 |
| 7 | xiaolong-upload | 安装视频号上传项目 |
| 8 | openclaw_upload | 安装图生视频项目 |
| 9 | Workspace 配置 | 复制模板 |
| 10 | Skills 安装 | 同步技能 |

## 当前边界

- `xiaolong-upload` 当前只对外开放视频号
- 其他平台实现代码可以保留在仓库中，但不通过主入口开放

# 龙虾上传

当前仓库对外只开放视频号自动上传能力。

说明：

- 根 CLI 只接受 `--platform shipinhao`
- 登录检查/补登录只支持视频号
- 抖音、快手、小红书目录暂时保留在仓库内，作为历史实现，不对外开放

## 快速开始

环境要求：

- Python 3.10+
- Google Chrome

安装依赖：

```bash
cd /path/to/xiaolong-upload
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## 统一 CLI

```bash
python upload.py --platform shipinhao <视频路径> [标题] [文案] [标签]
```

示例：

```bash
python upload.py -p shipinhao video.mp4 "标题" "文案" "标签1,标签2"
python upload.py -p shipinhao video.mp4 --login-only
```

## 批量入口

`upload_all.py` 仍然保留，但现在只包装视频号发布，方便兼容旧脚本：

```bash
python upload_all.py video.mp4 "标题" "文案" "标签1,标签2"
python upload_all.py video.mp4 --platform shipinhao
```

## 登录

首次运行会拉起视频号 connect Chrome，登录态保存在 `cookies/chrome_connect_sph/`。

常用命令：

```bash
python skills/auth/scripts/platform_login.py --platform shipinhao --check-only
python skills/auth/scripts/platform_login.py --platform shipinhao
python skills/auth/scripts/platform_login.py --platform shipinhao --notify-wechat
```

## 项目结构

```text
xiaolong-upload/
├── common/
├── platforms/
│   ├── shipinhao_upload/
│   ├── douyin_upload/      # 历史实现，当前不开放
│   ├── ks_upload/          # 历史实现，当前不开放
│   └── xhs_upload/         # 历史实现，当前不开放
├── skills/
├── upload.py
├── upload_all.py
└── requirements.txt
```

## 当前边界

- 对外发布入口：仅 `shipinhao`
- 对外登录入口：仅 `shipinhao`
- 其他平台代码：保留，不承诺可用，不在主入口暴露

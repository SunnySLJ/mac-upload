# Claude Init

本项目当前只对外开放一个发布目标：

- 视频号

说明：抖音、小红书、快手实现目录仍保留在仓库中，但不作为公开入口使用。

## 核心职责

### 1. auth 负责登录

`auth` 只负责：

- 检查登录是否可复用
- 打开登录页
- 等待用户完成登录
- 把登录信息写入 `cookies/chrome_connect_sph`

### 2. upload 负责发布

统一走：

```bash
python upload.py --platform shipinhao <video_path> [title] [description] [tags]
```

或：

```python
from upload import upload
```

## 当前公开端口与目录

- 视频号：`9226` + `cookies/chrome_connect_sph`

## 执行原则

1. 先检查登录，再发布。
2. 若用户要求“登录后先别发”，登录完成后必须停住等待确认。
3. 不要再把其他平台目录当作对外可用入口。

# longxia-deploy

`xiaolong-upload` 的安装入口保留不变，但当前只开放视频号。

## 安装

```powershell
cd "C:\Users\爽爽\Desktop\mac-openclaw\xiaolong-upload"
pip install -e . -i https://pypi.tuna.tsinghua.edu.cn/simple
```

安装后验证：

```powershell
longxia-upload --help
```

## 使用

```powershell
longxia-upload -p shipinhao "video.mp4" "标题" "文案" "标签1,标签2"
longxia-upload -p shipinhao "video.mp4" --login-only
```

## 说明

- `longxia-upload` CLI 只接受 `shipinhao`
- 其他平台代码目前不开放
- 如需补登录，使用 `skills/auth/scripts/platform_login.py --platform shipinhao`

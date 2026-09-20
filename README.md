<div align="center">

<img src="assets/icon.png" width="72" alt="Codex Glass">

# Codex Glass

**把 Codex 剩余额度，放在看得见的地方。**

Windows 10 / 11 · x64 · C# / WPF

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md)

![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?style=flat-square) ![Version](https://img.shields.io/badge/version-0.5.1-4C8DF3?style=flat-square) ![MIT](https://img.shields.io/badge/license-MIT-16A085?style=flat-square)

[下载最新版](https://github.com/qyyzclthsay/Codex-Glass/releases/latest) · [反馈问题](https://github.com/qyyzclthsay/Codex-Glass/issues) · [验证记录](docs/VALIDATION.md)

</div>

<table><tr><td align="center"><b>用量概览</b><br><img src="assets/preview-zh.png" width="300" alt="用量概览 · Demo"></td><td align="center"><b>深色主题</b><br><img src="assets/preview-dark.png" width="300" alt="深色主题 · Demo"></td></tr></table>

<p align="center"><img src="assets/preview-ring.png" width="92" alt="Idle ring · Demo"> <img src="assets/preview-ring-hover.png" width="92" alt="Hovered ring · Demo"><br><sub>平时只显示圆环，悬停显示数字；点击展开，拖动移动。截图均为演示数据。</sub></p>

## 小组件，随时可见

| 你关心的 | Codex Glass |
| --- | --- |
| 还剩多少 | 官方返回的 5 小时 / 每周额度、套餐与重置倒计时 |
| 其他模型 | 按模型分组，独立额度池不与主额度相加 |
| 每日用量 | 7 / 30 天 Token 柱状图，悬停或键盘查看数值 |
| 重置与会员 | 可用重置次数；会员日期手动填写、按账户保存 |
| 不挡住工作 | 迷你悬浮圆环、置顶、四角缩放、固定窗口内滚动 |
| 随你设置 | 简体 / 繁体 / English 菜单，浅色 / 深色 / 系统主题，自定义颜色 |

## 自定义颜色

打开 **设置 → 界面颜色**，让小组件配合你的桌面：

- **快速选择**：点击下方的六个预设色圆点。
- **自由选色**：点击右侧方形色块，打开 Windows 颜色选择器，选择自己的颜色。
- **恢复默认**：一键回到默认配色。

自定义颜色应用于按钮、进度条、正常状态的额度圆环；周期时间外环也跟随界面颜色。低额度的额度圆环仍保留橙色 / 红色提醒。

## 读懂两道圆环

在 **设置 → 圆环显示 → 周期时间外环** 中开启细外环（默认关闭），同时查看额度和时间：

| 圆环 | 表示什么 | 如何变化 |
| --- | --- | --- |
| 较粗的额度环 | 当前所选周期的**剩余额度** | 用量增加，剩余额度减少 |
| 较细的时间外环 | 同一周期的**已过时间比例** | 随时间推进增长，即使没有使用 Codex 也会变化 |

例如，5 小时周期已过去 2 小时，时间外环约走过 **40%**；额度环此时仍可能显示 **75% 剩余**。两者分别表示时间和额度，并不需要相加等于 100%。

外环依据官方返回的周期长度和重置时间计算，跟随当前选中的周期；缺少这些数据时不显示。百分比和周期文字在鼠标悬停时展开，带深色描边，兼顾浅色壁纸。

## 下载与开始使用

**[下载 Windows 安装包](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Setup-x64.exe)**

| 文件 | 用途 |
| --- | --- |
| [Setup-x64.exe](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Setup-x64.exe) | 推荐安装版，约 126 KiB |
| [Portable-x64.exe](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Portable-x64.exe) | 单文件便携版，约 187 KiB |
| [Portable-x64.zip](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Portable-x64.zip) | 便携版与许可证 |
| [SHA256SUMS](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/SHA256SUMS-0.5.1.txt) | 下载文件校验值 |

1. 在 Windows 10 / 11 x64 安装官方 Codex 桌面应用或 CLI，使本机可找到官方 Codex 可执行文件。
2. 安装或运行 Codex Glass。已有可读取的 ChatGPT 登录状态时，会自动显示额度；否则点击“使用 ChatGPT 登录”，在官方页面完成登录。
3. 顶部语言按钮可选择语言，双窗口图标进入迷你模式；拖标题栏或圆环移动。

构建尚未数字签名。已验证 Windows 10 22H2；Windows 11 与混合 DPI 尚未完整验证。

### 登录与自动读取

启动时自动检查本机 Codex 的当前账户并读取额度；**只有点击登录按钮才会发起浏览器登录**。“重新读取”仅重新检查账户和额度。

无需每次先打开 Codex 窗口，也无需让 Codex 桌面应用一直运行。组件会按需启动官方 `codex app-server`。如果桌面应用与组件使用不同的登录存储或运行环境，桌面端已登录也可能仍需在组件中连接。仅在浏览器登录 ChatGPT 不代表本机 Codex 已登录。

没有本机登录状态时，也可以直接从组件按钮完成首次登录，但仍需已安装官方 Codex。登录成功后自动读取额度；该操作可能更新本机 Codex CLI 的当前账户。组件不接收你的密码，OAuth 登录与凭据管理由官方 Codex 处理。API Key 登录不用于此处的 ChatGPT 订阅额度监控。接口说明见 [OpenAI 官方文档](https://developers.openai.com/zh-Hans/docs/app-server)。

## 体积与内存

C# / WPF 原生实现，使用 Windows 自带 .NET Framework，不捆绑 Electron、Chromium、Node.js 或 WebView2。安装包不包含系统框架和另行安装的官方 Codex。

**下载大小不等于运行内存。** 最新实测数据与条件见 [验证记录](docs/VALIDATION.md)。私有内存与工作集是不同口径，占用随系统、字体和操作变化。查询结束后释放 Codex 辅助进程；浏览器登录等待期间保留连接。

v0.5.0 本机基准实测：私有内存 **84.4 MiB**，工作集 **119.9 MiB**，查询后无辅助子进程。

## 数据与隐私

- 读取官方客户端返回的数据，不创建 AI 对话、不扫描聊天记录、不上传用量。
- 额度重置时间不等于会员到期时间，会员日期明确标记为手动填写。
- 每日记录可能延迟；缺失用 `—`，不冒充零；不同额度池分开显示。
- “重置”按钮只打开官方用量页，不直接消耗重置机会。
- 默认数据目录：`%APPDATA%\codex-usage-widget`。本地缓存未加密，请勿上传个人数据目录。

## 从源码构建

使用 Windows PowerShell 和系统 .NET Framework 编译器，无需 Node.js 或额外 SDK：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-native.ps1 -Test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/qa-native.ps1
```

安装包需安装 NSIS，再运行 `scripts/build-native.ps1 -Package`。产物位于 `dist/`。

| 环境变量 | 用途 |
| --- | --- |
| `CODEX_GLASS_NSIS_PATH` | 指定 `makensis.exe` |
| `CODEX_GLASS_CODEX_PATH` | 指定官方 Codex 可执行文件 |
| `CODEX_GLASS_DATA_DIR` | 指定组件数据目录 |

GitHub Actions 自动构建和测试；Release 由维护者发布。`native/` 是当前实现；`src/`、`tests/` 保留早期 Electron 参考源码，不编入当前程序。

## 开源

MIT · 社区独立项目，非 OpenAI 官方产品。服务 Logo 仅用于标识被监控服务。

[参与贡献](CONTRIBUTING.md) · [安全与隐私](SECURITY.md) · [技术架构](docs/ARCHITECTURE.md) · [第三方声明](THIRD_PARTY_NOTICES.md) · [更新记录](CHANGELOG.md)

感谢 [Pulse](https://github.com/qunqin24/Pulse) 提供功能逻辑参考；素材来源与许可保留在第三方声明中。

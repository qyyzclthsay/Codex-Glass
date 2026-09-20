<div align="center">

<img src="assets/icon.png" width="72" alt="Codex Glass">

# Codex Glass

**讓 Codex 剩餘額度，隨時看得見。**

Windows 10 / 11 · x64 · C# / WPF

[English](README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md)

![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?style=flat-square) ![Version](https://img.shields.io/badge/version-0.5.1-4C8DF3?style=flat-square) ![MIT](https://img.shields.io/badge/license-MIT-16A085?style=flat-square)

[下載最新版](https://github.com/qyyzclthsay/Codex-Glass/releases/latest) · [回報問題](https://github.com/qyyzclthsay/Codex-Glass/issues) · [驗證紀錄](docs/VALIDATION.md)

</div>

<table><tr><td align="center"><b>用量總覽</b><br><img src="assets/preview-zh-TW.png" width="300" alt="用量總覽 · Demo"></td><td align="center"><b>深色主題</b><br><img src="assets/preview-dark.png" width="300" alt="深色主題 · Demo"></td></tr></table>

<p align="center"><img src="assets/preview-ring.png" width="92" alt="Idle ring · Demo"> <img src="assets/preview-ring-hover.png" width="92" alt="Hovered ring · Demo"><br><sub>平時只顯示圓環，滑鼠停留時顯示數字；點擊展開，拖曳移動。截圖均為示範資料。</sub></p>

## 小元件，隨時可見

| 你關心的 | Codex Glass |
| --- | --- |
| 還剩多少 | 官方回傳的 5 小時 / 每週額度、方案及重設倒數 |
| 其他模型 | 依模型分組，獨立額度池不與主額度相加 |
| 每日用量 | 7 / 30 天 Token 長條圖，滑鼠停留或鍵盤查看數值 |
| 重設與會員 | 可用重設次數；會員日期手動填寫、依帳戶儲存 |
| 不遮擋工作 | 迷你懸浮圓環、置頂、四角縮放、固定視窗內捲動 |
| 隨你設定 | English / 簡體 / 繁體 選單，淺色 / 深色 / 系統主題，自訂色彩 |

## 🎨 選一個你的色彩

在 **設定 → 介面色彩** 中選擇預設色，或點擊右側的**方形色塊**，自由挑選色彩。

<table><tr><td align="center"><b>選擇色彩</b><br><img src="assets/guide-color-zh-TW.png" width="354" alt="實際色彩設定：六種預設、自訂色塊與還原預設"></td><td align="center"><b>看看桌面效果</b><br><img src="assets/guide-color-rings-zh-TW.png" width="354" alt="藍色、紫色、綠色的小元件效果 · 示範資料"></td></tr></table>

按鈕、進度條與圓環跟隨你的配色；低額度仍保留橙紅色提醒。點擊**還原預設**即可還原。

## ⏱ 額度與時間，一起看

在 **設定 → 圓環顯示** 中開啟**週期時間外環**。粗環看**還剩多少額度**，細外環看**週期已過多久**。

<table><tr><td align="center"><b>開啟時間外環</b><br><img src="assets/guide-ring-settings-zh-TW.png" width="354" alt="為五小時週期開啟週期時間外環"></td><td align="center"><b>關閉 / 開啟</b><br><img src="assets/guide-ring-zh-TW.png" width="354" alt="相同的 75% 剩餘額度，左邊關閉時間外環，右邊開啟 · 示範資料"></td></tr></table>

圖中範例：**額度還剩 75%**，**5 小時週期已過去 40%**。外環跟隨介面色彩，可隨時關閉；滑鼠停留在圓環上即可查看數字。

## 下載與開始使用

**[下載 Windows 安裝程式](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Setup-x64.exe)**

| 檔案 | 用途 |
| --- | --- |
| [Setup-x64.exe](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Setup-x64.exe) | 推薦安裝版，約 126 KiB |
| [Portable-x64.exe](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Portable-x64.exe) | 單檔可攜版，約 187 KiB |
| [Portable-x64.zip](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Portable-x64.zip) | 可攜版與授權文件 |
| [SHA256SUMS](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/SHA256SUMS-0.5.1.txt) | 下載檔案校驗值 |

1. 在 Windows 10 / 11 x64 安裝官方 Codex 桌面應用程式或 CLI，讓本機能找到官方 Codex 執行檔。
2. 安裝或執行 Codex Glass。已有可讀取的 ChatGPT 登入狀態時，會自動顯示額度；否則點擊「使用 ChatGPT 登入」，在官方頁面完成登入。
3. 頂部語言按鈕可選擇語言，雙視窗圖示切換迷你模式；拖曳標題列或圓環移動。

程式尚未數位簽章。已驗證 Windows 10 22H2；Windows 11 與混合 DPI 尚未完整驗證。

<details>
<summary>登入與自動讀取</summary>

啟動時自動檢查本機 Codex 的目前帳戶並讀取額度；**只有點擊登入按鈕才會啟動瀏覽器登入**。「重新讀取」僅重新檢查帳戶與額度。

不必每次先開啟 Codex 視窗，也不必讓 Codex 桌面應用程式持續執行。元件會按需啟動官方 `codex app-server`。若桌面應用程式與元件使用不同的登入儲存位置或執行環境，桌面端已登入也可能仍需在元件中連線。僅在瀏覽器登入 ChatGPT 不代表本機 Codex 已登入。

沒有本機登入狀態時，也可以直接從元件按鈕完成首次登入，但仍須已安裝官方 Codex。登入成功後自動讀取額度；此操作可能更新本機 Codex CLI 的目前帳戶。元件不接收你的密碼，OAuth 登入與憑證管理由官方 Codex 處理。API Key 登入不適用於此處的 ChatGPT 訂閱額度監控。介面說明見 [OpenAI 官方文件](https://developers.openai.com/zh-Hant/docs/app-server)。

</details>

## 體積與記憶體

C# / WPF 原生實作，使用 Windows 提供的 .NET Framework，不附帶 Electron、Chromium、Node.js 或 WebView2。安裝程式不包含系統框架與另行安裝的官方 Codex。

**下載大小不等於執行記憶體。** 最新實測數據與條件見 [驗證紀錄](docs/VALIDATION.md)。私有記憶體與工作集是不同指標，用量會隨系統、字型與操作改變。查詢結束後釋放 Codex 輔助程序；瀏覽器登入等待期間保留連線。

v0.5.0 本機基準實測：私有記憶體 **84.4 MiB**，工作集 **119.9 MiB**，查詢後無輔助子程序。

## 資料與隱私

- 讀取官方用戶端回傳的資料，不建立 AI 對話、不掃描聊天紀錄、不上傳用量。
- 額度重設時間不等於會員到期時間，會員日期明確標示為手動填寫。
- 每日紀錄可能延遲；缺少資料以 `—` 顯示，不當作零；各額度池分別顯示。
- 「重設」按鈕僅開啟官方用量頁面，不直接消耗重設機會。
- 預設資料目錄：`%APPDATA%\codex-usage-widget`。本機快取未加密，請勿上傳個人資料目錄。

## 從原始碼建置

使用 Windows PowerShell 與系統 .NET Framework 編譯器，無需 Node.js 或額外 SDK：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-native.ps1 -Test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/qa-native.ps1
```

安裝程式需安裝 NSIS，再執行 `scripts/build-native.ps1 -Package`。產物位於 `dist/`。

| 環境變數 | 用途 |
| --- | --- |
| `CODEX_GLASS_NSIS_PATH` | 指定 `makensis.exe` |
| `CODEX_GLASS_CODEX_PATH` | 指定官方 Codex 執行檔 |
| `CODEX_GLASS_DATA_DIR` | 指定元件資料目錄 |

GitHub Actions 自動建置與測試；Release 由維護者發布。`native/` 是目前實作；`src/`、`tests/` 保留早期 Electron 參考原始碼，不編入目前程式。

## 開源

MIT · 社群獨立專案，非 OpenAI 官方產品。服務 Logo 僅用於識別受監控的服務。

[參與貢獻](CONTRIBUTING.md) · [安全與隱私](SECURITY.md) · [技術架構](docs/ARCHITECTURE.md) · [第三方聲明](THIRD_PARTY_NOTICES.md) · [更新紀錄](CHANGELOG.md)

感謝 [Pulse](https://github.com/qunqin24/Pulse) 的功能邏輯參考；素材來源與授權保留於第三方聲明。

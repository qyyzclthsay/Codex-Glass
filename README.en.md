<div align="center">

<img src="assets/icon.png" width="72" alt="Codex Glass">

# Codex Glass

**Your Codex allowance. Always in view.**

Windows 10 / 11 · x64 · C# / WPF

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md)

![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?style=flat-square) ![Version](https://img.shields.io/badge/version-0.5.1-4C8DF3?style=flat-square) ![MIT](https://img.shields.io/badge/license-MIT-16A085?style=flat-square)

[Download](https://github.com/qyyzclthsay/Codex-Glass/releases/latest) · [Report an issue](https://github.com/qyyzclthsay/Codex-Glass/issues) · [Validation](docs/VALIDATION.md)

</div>

<table><tr><td align="center"><b>Usage overview</b><br><img src="assets/preview-en.png" width="300" alt="Usage overview · Demo"></td><td align="center"><b>Dark theme</b><br><img src="assets/preview-dark.png" width="300" alt="Dark theme · Demo"></td></tr></table>

<p align="center"><img src="assets/preview-ring.png" width="92" alt="Idle ring · Demo"> <img src="assets/preview-ring-hover.png" width="92" alt="Hovered ring · Demo"><br><sub>Hover for numbers. Click to expand. Drag to move. All screenshots use demo data.</sub></p>

## A small companion for your desktop

| At a glance | What you get |
| --- | --- |
| Remaining allowance | Service-reported 5-hour / weekly windows, plan and reset countdowns |
| Additional models | Separate model groups; independent pools never added to primary quotas |
| Daily usage | Flat 7 / 30-day token charts with hover and keyboard values |
| Resets & membership | Available resets; manual membership dates saved per account |
| Stay out of the way | Floating ring, pinning, corner resizing and scrolling within a fixed window |
| Make it yours | Simplified Chinese / Traditional Chinese / English menu, light / dark / system themes, custom accents |

The elapsed-time arc follows your accent. Outlined percentage and period labels stay legible on light wallpapers. Low allowance retains amber/red warning colors.

## Download & get started

**[Download the Windows installer](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Setup-x64.exe)**

| File | Purpose |
| --- | --- |
| [Setup-x64.exe](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Setup-x64.exe) | Recommended installer, about 126 KiB |
| [Portable-x64.exe](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Portable-x64.exe) | Standalone executable, about 187 KiB |
| [Portable-x64.zip](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Portable-x64.zip) | Portable executable and licenses |
| [SHA256SUMS](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/SHA256SUMS-0.5.1.txt) | Download checksums |

1. Install the official Codex desktop app or CLI on Windows 10 / 11 x64 and sign in with ChatGPT.
2. Install or run Codex Glass. It reads the current account through local Codex.
3. Pick a language from the top menu. The overlapping-windows icon opens compact mode. Drag the title bar or compact ring to move.

If sign-in is needed, the official page opens in your system browser. This may change the local CLI account. Builds are unsigned. Validated on Windows 10 22H2; Windows 11 and mixed-DPI configurations are not fully tested.

## Size & memory

C# / WPF using the Windows-provided .NET Framework. No bundled Electron, Chromium, Node.js or WebView2. Downloads exclude the system framework and the separately installed official Codex runtime.

**Download size is not RAM usage.** See the [validation record](docs/VALIDATION.md) for current measurements and conditions. Private memory and working set are different metrics; usage varies with system, fonts and activity. The Codex helper exits after queries and stays connected only while browser sign-in is pending.

Reference measurement (v0.5.0, compact mode): **84.4 MiB private memory**, **119.9 MiB working set**, with no helper child after the query.

## Data & privacy

- Reads official client responses. No AI conversations created, no chat history scanned, no usage uploaded.
- Quota reset dates are not membership expiry dates. Membership dates are explicitly manual.
- Daily reports may be delayed. Missing values remain `—`, distinct from zero. Pools stay separate.
- Reset opens the official usage page; it does not consume a reset credit.
- Default storage: `%APPDATA%\codex-usage-widget`. Local caches are not encrypted. Keep personal data directories out of public reports.

## Build from source

Use Windows PowerShell and the system .NET Framework compiler. No Node.js or extra SDK required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-native.ps1 -Test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/qa-native.ps1
```

Install NSIS for packaging, then run `scripts/build-native.ps1 -Package`. Output goes to `dist/`.

| Environment variable | Purpose |
| --- | --- |
| `CODEX_GLASS_NSIS_PATH` | Path to `makensis.exe` |
| `CODEX_GLASS_CODEX_PATH` | Path to the official Codex executable |
| `CODEX_GLASS_DATA_DIR` | Widget data directory |

GitHub Actions builds and tests; maintainers publish Releases. The current implementation is in `native/`. Historical Electron code in `src/` and `tests/` is retained for reference and excluded from the current binary.

## Open source

MIT · Independent community project, not an official OpenAI product. Service logos identify the monitored service.

[Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Architecture](docs/ARCHITECTURE.md) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Changelog](CHANGELOG.md)

Thanks to [Pulse](https://github.com/qunqin24/Pulse) for functional inspiration. Asset origins and licenses are preserved in the third-party notices.

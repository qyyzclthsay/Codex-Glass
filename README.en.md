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

## Choose your colors

Open **Settings → Accent color** to match the widget to your desktop:

- **Pick a preset:** select one of the six color circles.
- **Choose a custom color:** click the square swatch on the right to open the Windows color picker.
- **Restore defaults:** return to the original palette with one click.

Your custom accent applies to buttons, progress bars and the allowance ring in its normal state. The elapsed-time outer ring follows the interface accent too. Low allowance still uses amber / red warning colors on the allowance ring.

## Two rings, two readings

Enable **Settings → Status ring → Elapsed time arc** (off by default) to see allowance and time together:

| Ring | What it shows | How it changes |
| --- | --- | --- |
| Thick allowance ring | **Remaining allowance** in the selected window | Falls as allowance is used |
| Thin outer ring | **Elapsed time** as a share of the same window | Advances with time, even when you are not using Codex |

For example, two hours into a five-hour window, the outer ring is about **40%** complete while the allowance ring might still show **75% remaining**. They measure different things and do not need to add up to 100%.

The outer ring uses the service-reported window duration and reset time, following the currently selected window. It is hidden when those values are unavailable. Hover to reveal the percentage and period labels; dark outlines keep them readable on light wallpapers.

## Download & get started

**[Download the Windows installer](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Setup-x64.exe)**

| File | Purpose |
| --- | --- |
| [Setup-x64.exe](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Setup-x64.exe) | Recommended installer, about 126 KiB |
| [Portable-x64.exe](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Portable-x64.exe) | Standalone executable, about 187 KiB |
| [Portable-x64.zip](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/Codex-Glass-0.5.1-Portable-x64.zip) | Portable executable and licenses |
| [SHA256SUMS](https://github.com/qyyzclthsay/Codex-Glass/releases/latest/download/SHA256SUMS-0.5.1.txt) | Download checksums |

1. Install the official Codex desktop app or CLI on Windows 10 / 11 x64 so the official Codex executable is available locally.
2. Install or run Codex Glass. It reads an available ChatGPT sign-in automatically. Otherwise, click “Sign in with ChatGPT” and complete sign-in on the official page.
3. Pick a language from the top menu. The overlapping-windows icon opens compact mode. Drag the title bar or compact ring to move.

Builds are unsigned. Validated on Windows 10 22H2; Windows 11 and mixed-DPI configurations are not fully tested.

### Sign-in and automatic reading

On startup, the widget checks the current local Codex account and reads its allowance. **Browser sign-in starts only when you click the sign-in button.** “Read again” only retries the account and allowance check.

You do not need to open a Codex window first or keep the desktop app running. The widget starts the official `codex app-server` when needed. If the desktop app and widget use different credential stores or environments, you may still need to connect in the widget. Signing in to ChatGPT in a browser alone does not sign in to local Codex.

You can complete your first sign-in from the widget, provided official Codex is installed. After a successful sign-in, allowance is read automatically; this may update the current local Codex CLI account. The widget does not receive your password. Official Codex manages OAuth and credentials. API-key sign-in is not used for this ChatGPT subscription allowance monitor. See the [official OpenAI documentation](https://developers.openai.com/codex/app-server) for the account interface.

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

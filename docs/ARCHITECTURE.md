# Native architecture (v0.4.0)

## macOS preview (0.6.0-beta.1)

`macos/` is a separate native SwiftUI/AppKit executable using the same official
account protocol as the Windows implementation. `CodexGlassCore` owns typed data,
normalization, local storage and a bounded, short-lived JSON-RPC subprocess.
The executable owns native windows, the menu-bar item, compact ring drawing,
notifications and login-item preferences. There are no external Swift packages.
See [macOS setup and validation](MACOS.md). Windows source and packaging stay separate.

- `native/Core.cs`: bounded JSON helpers, normalization, account hashing, cache/date validation,
  atomic storage and async JSON-RPC over a directly spawned hidden Codex process.
- `native/Service.cs`: serialized read transactions, verified account boundaries, short in-memory
  daily history cache, plan quota cache, browser-login lifecycle and deduplicated alerts.
- `native/Window.cs`: WPF overview, footer, tray, native window gestures, bounds and theme.
- `native/SettingsView.cs`: bilingual preferences, native color picker and manual membership form.
- `native/Visuals.cs`: vector ring and flat token chart, directly drawn with WPF.
- `native/Program.cs`: entry point, profile-specific single instance, lifecycle and test switches.
- `native/Tests.cs`: native core, real child-process protocol fixtures, UI QA and opt-in live measurement.
- `scripts/build-native.ps1`: compiles a standalone x64 .NET Framework executable with system tools.

## Size and runtime

No browser engine or third-party runtime is distributed. Windows supplies .NET Framework/WPF;
this is a real runtime dependency, not part of the small download. The application is managed C#
and JIT-compiled by the system CLR. The supported API surface is compatible with .NET 4.6.
The existing Windows runtime handles security updates; the project does not ship an old CLR.
Software rendering is selected for these small static widgets to avoid dedicated GPU resources.
No periodic working-set trimming or artificial RAM-clearing is used to inflate benchmarks.

Quota and daily transactions are serialized. The helper exits after each transaction; browser
login temporarily keeps it alive until completion/cancel/five-minute timeout. Polling remains
2 minutes by default, at least 10 minutes hidden, with backoff and sleep/resume support.
Only clocks/ring elapsed position are redrawn every 15 seconds; no perpetual animation loop.

## Windows and settings

Default overview size 382 × 580 DIPs, capped by the current display. Expanding sections
keeps the window size and scrolls the content, with scroll position retained on refresh. Four native Thumb
controls resize from the corners, keeping the opposite corner stationary. Manual dimensions
are saved (minimum 320 × 360, maximum 900 × 1400, capped by work area); contents scroll.
Mini remains 92 × 126 DIPs, with its own transparent vector drawing, logo, percentage and period.
The title bar moves the main window; the mini distinguishes click from drag. Right-click menus
include a size reset. Positions are kept visible after display changes.

The settings JSON format and default `%APPDATA%/codex-usage-widget` directory remain compatible
with v0.3. The test/development override `CODEX_GLASS_DATA_DIR` is honored. Account data is
hashed before persistence. Manually entered membership dates remain isolated by account.

## Data boundaries

Quota reads: account/read → account/rateLimits/read → account/read. Account changes invalidate
in-memory history and the current quota before any data from the new account is displayed.
Cached quota expires after 24 hours, loses expired windows and never retains consumable reset
counts as current. Missing values remain unavailable. Only primary Codex pools participate
in automatic ring selection; independent model pools are shown separately.

Daily reads: account/read → account/usage/read → account/read, checking the verified account
fingerprint and generation. Dates and nonnegative integer token counts alone are retained;
per-thread fields are discarded. Missing dates differ from zero. Conflicting duplicate dates
are excluded and labeled incomplete. Daily history stays in memory for at most the current
account and a short 60-second refresh cache; it is not written to disk.

Browser login is delegated to the official runtime. The widget never reads auth.json, handles
passwords, creates AI turns or consumes reset credits. Reset opens the official usage page.

## Historical implementation

`src/`, `tests/`, and `docs/electron-package-v031.json` preserve the earlier Electron implementation
for reference and comparison. They are not compiled or bundled into v0.4. No Node installation
is needed to build or run the native app. The previous architecture description is preserved
in the v0.3 source releases.

# Changelog

## 0.5.1 — 2026-09-20

- Made the inactive ring track translucent while retaining the original center color.
- Hide compact-mode percentage and period labels until the pointer enters the circle.
  Labels slide/fade in over 180 ms and retract over 140 ms; text styling is unchanged.
- Respect Windows' animation preference. Finished and interrupted animations release
  their clocks; caption drawings are cached instead of rebuilding text every frame.

## 0.5.0 — 2026-09-20

- Added Traditional Chinese throughout the interface, preferences and notifications.
- Replaced the two-language toggle with a three-language menu and current-choice checkmark.
- Made dates follow the selected interface language instead of the Windows regional language.
- Added Simplified Chinese, Traditional Chinese and English project pages with fresh demo screenshots.
- Fixed concurrent pending-request cleanup when the Codex helper exits or the widget closes.
- Prevented initialization account notifications from triggering redundant refreshes.
- Preserved fixed-size scrolling, draggable title bars, model-pool headings, accent-colored
  elapsed arcs, and outlined mini-mode labels from the 0.4 series.

## 0.4.0–0.4.5

- Replaced Electron with native C# / WPF using the system .NET Framework.
- Added saved corner resizing and bounded scrolling.
- Improved model-pool layout, compact ring styling and readability on light wallpapers.

See [validation](docs/VALIDATION.md) for test conditions, memory measurements and known limits.

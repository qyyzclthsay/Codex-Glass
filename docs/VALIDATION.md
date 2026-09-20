# Validation record — native update 2026-09-20

## v0.5.0 release

- 39 core/protocol assertions passed, including three-language catalog coverage,
  Traditional Chinese preference persistence, English date culture, and concurrent
  cancellation of pending helper requests. The native UI suite passed language-menu
  selections, saved language choice, three localized settings/overview screens, existing
  resize/scroll checks, chart ranges, colors, membership and mini-mode checks.
- A real-account run read quota and 28 daily buckets successfully, with no remaining
  helper and a clean exit. This run exposed and led to fixes for pending-request dictionary
  reentrancy during shutdown and redundant refreshes from initialization notifications.
- Normal mini launch with the existing profile, after the query completed: **84.4 MiB
  private memory, 119.9 MiB working set, zero child processes**. Installer size and RAM
  are separate. This is a process snapshot, not a peak bound or a promise of <100 MiB.
- Separate real-account measurement without screenshot allocation:

  | View | Private memory (MiB) | Working set (MiB) |
  | --- | ---: | ---: |
  | Main | 87.5 | 123.9 |
  | Daily chart | 88.0 | 125.5 |
  | Mini after main/chart | 89.0 | 126.1 |

  Windows 10 22H2 x64, software-rendered WPF; Windows framework pages are included.
  No forced garbage collection or working-set trimming. Earlier 59–60 MiB readings were
  preliminary, before the final concurrency fix, and are not the release baseline.
- All public screenshots are generated from demo fixtures, with the Demo label visible.
  Real account caches, settings, credentials and private test outputs are excluded.
- Known limits: unsigned installer; Windows 11, mixed-DPI monitor changes, fresh OAuth
  login and physical mouse gesture automation have not been fully verified here.

## v0.4.5 mini-ring legibility

- Increased the elapsed arc from 1.1 to 2 DIP, with rounded ends; the quota ring
  remains 5 DIP. The elapsed arc still follows the interface accent.
- Added dark glyph outlines behind the white percentage and period text, using
  vector geometry with hinted text on top, without blur effects or wallpaper reads.
- Native UI QA passed. Visually checked actual widget renders on white, light-gray,
  and dark backgrounds; mini dimensions remain 92 × 126 DIP.

## v0.4.4 elapsed-ring accent

- The elapsed-time outer arc uses the current interface accent instead of a fixed
  pale blue. The inner quota ring retains its existing warning/status colors.
- Native UI QA passed; default-accent and custom purple ring captures were visually checked.

## v0.4.3 allowance layout and bounded scrolling

- Restored the separate-pool model heading, right-aligned pool count badge, calendar
  icon, small scope label, and percentage suffix with remaining label.
- Removed content-dependent overview resizing. Default size is 382 × 580 DIP;
  saved manual dimensions still apply. Added a slim vertical scrollbar and retained
  scroll position when refreshing or expanding sections in the same view.
- Final core suite passed (31 assertions). UI suite passed including fixed height
  on pool/daily expansion, visible overflow scrollbar, scrollbar page-down command,
  model heading, scroll position after refresh, four-corner sizing, and mini restoration.
- Visually checked Chinese/English expanded layouts and the final slim scrollbar.

## v0.4.2 expanded allowance spacing

- Added 14 DIP bottom spacing and a 16 DIP line height to the separate-pool
  explanation so wrapped text does not touch the quota card border.
- Native UI smoke checks passed. Chinese and English expanded-pool screenshots
  were visually checked at the minimum 320 DIP window width.

## v0.4.1 title-bar dragging

- The complete title bar now participates in hit testing, including blank space and
  padding. Logo/title descendants initiate moving; header button descendants do not.
- Refreshes are deferred during the native move loop; snapping and saving happen after
  release, preventing the location timer from snapping the window during a drag.
  Mini-ring dragging shares the same guarded move routine.
- Final executable: 164,352 bytes. Core tests (31 assertions) and native UI QA passed,
  including new actual visual-tree hit tests for blank title-bar points, logo/title,
  all four header buttons, and refresh deferral. Existing corner-sizing checks passed.
- Installer extraction produced an executable identical to the portable version.
- Desktop input QA was attempted using an isolated demo profile. The Windows capture
  helper failed with `SetIsBorderRequired: E_NOINTERFACE`; input also reported
  `coordinate input geometry is unavailable`. Physical pointer gestures remain unverified.
  `--demo --interactive-test` exposes the demo window in the taskbar for future UI QA.

## v0.4.0 native

- C# / WPF built with the system .NET Framework compiler on Windows 10 Pro 22H2.
  No bundled CLR, browser engine, Node.js, WebView2 or downloaded SDK.
- Final portable executable: 162,304 bytes. Installer and portable ZIP are separately
  compressed; sizes and SHA-256 hashes are recorded with the release artifacts.
- 31 native core/protocol assertions passed: quota pools and labels, missing vs zero,
  account/cache isolation, expiry, daily duplicate handling and date ranges, preferences,
  atomic storage, concurrent RPC correlation, helper restart and EOF cleanup.
- Final portable UI QA passed: nonblank screenshots, Chinese/English, light/dark,
  7/30-day chart, minimum-width scrolling, settings, persisted colors/membership,
  four-corner sizing geometry, mini/main restoration, pinned weekly ring and signed-out UI.
  This tests native controls and sizing geometry; it is not a full physical-mouse gesture test.
- Actual account read and daily history query succeeded (28 service date buckets).
  The helper process was no longer running after the reads. No credentials or transcripts
  were read/copied; private live screenshots are excluded from source archives.
- Actual software-rendered run, after successful reads: main private 91,856,896 bytes,
  chart private 97,169,408 bytes, mini private 96,104,448 bytes. Corresponding working sets:
  130,572,288 / 136,835,072 / 134,574,080 bytes. These are snapshots on this machine, not
  guarantees or peak bounds. UI stress/screenshot tests allocate more memory. No manual GC
  or working-set trimming is used. System framework memory is included in measurements.
- A separate normal launch with the existing user profile in mini mode measured 80.1 MiB
  private memory and 113.7 MiB working set after a successful quota read; zero child processes
  remained. This run did not execute the screenshot test harness.
- Installer extraction mode passed: executable hash matches the final standalone executable;
  MIT and third-party license files present. Extraction mode does not create shortcuts or
  registry entries. Interactive installation/uninstallation has not been exercised.
- Current build is unsigned. Windows 11, mixed-DPI moves during resize, native notification
  delivery, startup registration and a fresh OAuth login remain unverified on this machine.
- GitHub publication is not performed; source, workflow and local release artifacts are ready.

## Historical Electron records — 2026-09-19

This file records actual checks, rather than claiming support from the target specification.

## v0.3.1

- 37 core tests passed, including four-corner opposite-anchor preservation, size limits,
  negative-coordinate monitor geometry and saved-size sanitization.
- UI tests exercised all four corners with trusted mouse input, saved dimensions, restoration
  after settings/mini transitions, and scrollable 320 × 420 layouts without horizontal overflow.
- Daily chart checked with 7/30 bars, chronological order and hover details. Existing quota,
  logo dragging, membership, custom color and bilingual checks passed.
- Final portable v0.3.1 passed the same UI suite (exit 0), including the narrow English layout,
  with no renderer errors. Installer and portable x64 packages built successfully.
- Actual multi-monitor/DPI changes during a resize gesture remain unverified.

## v0.3.0

- 34 core tests passed, including daily normalization, missing/zero dates, duplicate handling,
  request coalescing, short cache expiry and account-change invalidation.
- Authenticated read of `account/usage/read` succeeded through the local Codex runtime,
  returning 27 daily buckets. No transcript files or credentials were read/copied.
- Development and final portable UI checks passed for 7/30-day expansion, reset URL routing (stubbed; no credit
  consumption), settings-before-mini toolbar order, and at least 10 DIPs of vertical space
  around help text. Existing dragging, color, membership and quota-state checks passed.
- Daily figures use service-provided dates and may be delayed; missing days are not zero.

## v0.2.3 historical checks

- Visual/UI checks passed: mini window reduced to 92 × 126 DIPs, ring graphic 72 DIPs,
  service logo enlarged from 28 to 34 DIPs. Percentage and period remain visible.
- Logo-origin dragging and click expansion passed; zero image-drag events or renderer errors.
- Existing light/dark, color persistence, membership, quota-state and layout checks passed.

## v0.2.2 historical checks

- 27 core tests passed, including persisted color validation. Development and final portable
  UI checks both exited 0.
- Custom color changes survived settings persistence; inspected light/dark cards and picker.
- Compact period name restored; window is 112 × 146 DIPs. Mini/settings icons are in the top
  toolbar; the hide-to-tray button is absent.
- Electron mouse input events supplied with screen coordinates dragged directly from the
  logo center: window moved 32 DIPs left / 28 down, zero HTML image-drag events, no accidental
  expansion. Subsequent click expanded correctly. Quota/error state checks remained passing.

## v0.2.1 historical checks

- 27 core tests passed. Development and final portable UI checks both exited 0.
- Restored Microsoft-style light/dark cards; removed heading tagline and compact period text.
- Compact window is 112 × 130 DIPs. OpenAI SVG rendered successfully; click-to-expand,
  dragging, window selection, cached/low/unknown states and membership editing still passed.
- Cached compact readings use a gray ring and clock icon, with detail in the tooltip.
- Native backdrop helper is removed from source, scripts and final packaged resources.
- Final portable and NSIS packages built; screenshots below use demonstration data only.

## v0.2.0 historical checks

- Core tests: 27 passing (quota parsing, unknown values, account-bound cache, invalid local
  files, dates, notification deduplication, JSON-RPC concurrency, timeouts, EOF and restart).
- JavaScript syntax checks: passed.
- Dependency audit at install: 0 reported vulnerabilities.
- Real local Codex helper: executable discovery, JSON-RPC handshake, current-account read
  and authenticated quota retrieval succeeded outside the restricted shell. The service
  returned the main weekly pool, an additional pool, and reset-credit metadata.
  The initial restricted-shell probe could not access Windows credentials; normal Windows
  credential access resolved this. No credential was copied or printed. New browser login
  completion has not been exercised because the existing account worked.
- UI smoke test on Windows 10 Pro 22H2 (build 19045): passed. Chinese / English,
  light / dark, settings, membership save, compact / expanded and signed-out views
  captured. No renderer errors or horizontal overflow. Compact window verified at
  112 × 142 logical pixels. Full demo card 382 × 768; settings 382 × 740.
  Ring automatically selected 68% primary allowance and switched to 82% on pinning weekly.
  A separate 100% reserve pool stayed out of the ring. Low, stale and missing-main-window
  fixtures checked; unavailable main allowance displayed a dash. Pointer-movement IPC moved
  the window; clicking the ring restored the 382-DIP main window. Model details expanded
  without horizontal overflow.
- Native Windows 10 backdrop helper returned success in glass mode and disabled blur in
  ring/clear/solid modes. Renderer screenshots verify layout, not the exact appearance of
  the desktop behind the window. Apple's Liquid Glass/refraction is not implemented.
  Final light-mode PNG samples away from text/borders had alpha 39–82 / 255, confirming
  that the renderer surface itself is transparent. Compact outer background alpha was zero.
- Electron runtime SHA-256 verified against the installed package's checksum list.
- Electron graphics subprocesses cannot run inside this environment's restricted shell;
  UI checks succeeded outside that shell with the application's renderer sandbox enabled.
- NSIS installer and portable x64 executables built successfully (~106 MB each), unsigned.
  Both the unpacked executable and final portable launcher passed UI checks, including
  membership editing and compact sizing. The portable build was then opened with real usage.
  Version 0.1 was previously opened with real usage. Version 0.2 adds the native helper.
  Final v0.2 portable executable passed the expanded UI suite (exit 0), including native
  backdrop success from its shipped 4.5 KB helper. Product metadata reports 0.2.0.
- Windows 11 backdrop appearance, additional display scaling / monitor / login-provider combinations,
  installed startup registration and native notification delivery are not yet verified.
- GitHub publication: not performed. The local GitHub CLI is not authenticated.

Demo screenshots contain fixtures and must not be presented as a real account reading.

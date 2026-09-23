# Third-party notices

Codex Glass is an independent community project, not an OpenAI product.
Codex and ChatGPT are names of OpenAI products. The OpenAI Blossom in the quota ring
identifies the monitored service. It is not this application's own logo and does not
indicate endorsement. OpenAI retains its trademark rights.

`assets/openai.svg` is the unmodified OpenAI icon resource from
[Pulse](https://github.com/qunqin24/Pulse/blob/54f55c412f18b835fc10b95f1497dadb16df5584/Sources/Pulse/Resources/openai.svg),
retrieved from commit `54f55c412f18b835fc10b95f1497dadb16df5584`. Pulse's Apache-2.0
license accompanies this resource in `licenses/Pulse-Apache-2.0.txt`.
Trademark use is distinct from that source license; see https://openai.com/brand/.

The macOS preview reuses that SVG and a derived native vector path in
`macos/Sources/CodexGlass/LogoPath.swift`. The same attribution, source license,
and trademark restrictions apply. SwiftUI, AppKit, Foundation, Combine, CryptoKit,
ServiceManagement and UserNotifications are Apple platform frameworks, not vendored libraries.

Version 0.4 uses Windows-provided .NET Framework and WPF. These Microsoft system
components are not redistributed in the application packages. NSIS is used to produce
the installer; its license is documented at https://nsis.sourceforge.io/License.

The historical v0.3 Electron implementation is retained in source for reference only.
Electron/Chromium and electron-builder are not included in v0.4 distribution artifacts.

The official Codex runtime is a separate, user-installed dependency; this project
does not redistribute it or copy credentials from it.

Acknowledgement: [Pulse](https://github.com/qunqin24/Pulse) was reviewed as a reference
for quota windows, stale readings, and refresh behavior. The OpenAI icon resource above
is the sole copied asset; application code and layout are independently implemented.

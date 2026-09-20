# Contributing

Use Windows PowerShell and the system .NET Framework compiler. Run
`scripts/build-native.ps1 -Test` and `scripts/qa-native.ps1` before submitting a PR.
The active implementation is in `native/`; the old Electron source is reference-only.
UI screenshots use fixture data and must show the Demo label. Test data must never contain
real credentials, account identifiers or email addresses.

Keep quota parsing independent of UI. Preserve unknown data as unknown, keep original
timestamps, and never infer subscription expiration from token or quota reset timestamps.
Keep Simplified Chinese, Traditional Chinese and English catalogs complete. Test narrow widths and both themes.

Do not add undocumented endpoint fallbacks, credential copying or telemetry without a
clearly documented design discussion. Do not create a thread or turn to query usage.

See README for local build commands. Builds are unsigned unless maintainers explicitly
configure a signing workflow. Publishing is not part of the default CI workflow.

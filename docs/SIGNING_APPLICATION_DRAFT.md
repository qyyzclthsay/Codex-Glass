# Free open-source signing application — draft

**Prepared for maintainer review. Not submitted; no sponsorship or approval claimed.**

Application entry point: https://signpath.org/apply

| Field | Prepared information |
| --- | --- |
| Project | Codex Glass |
| Maintainer | theSay, GitHub account `qyyzclthsay` |
| Repository | https://github.com/qyyzclthsay/Codex-Glass |
| License | MIT, with third-party notices and licenses in the repository |
| Releases | https://github.com/qyyzclthsay/Codex-Glass/releases |
| Platform | Windows 10 / 11 x64 |
| Implementation | C# / WPF, system .NET Framework; official Codex installed separately |
| Build | Public GitHub Actions Windows build; source under `native/` |
| Requested artifacts | Native executable, NSIS installer and generated uninstaller |
| Privacy | https://github.com/qyyzclthsay/Codex-Glass/blob/main/SECURITY.md |
| Signing policy | https://github.com/qyyzclthsay/Codex-Glass/blob/main/docs/CODE_SIGNING.md |

## Project description

Codex Glass is an open-source Windows desktop widget that displays Codex account
allowance and daily token statistics through the locally installed official Codex
runtime. It offers a compact desktop ring, usage charts, custom colors and English,
Simplified Chinese and Traditional Chinese interfaces. It contains no developer
telemetry and makes no AI model calls. Official Codex handles authentication and
account queries with OpenAI.

We would like a verifiable signing process linking public source revisions to
release binaries. The project is newly released and may not yet meet the
Foundation's reputation requirements. We do not claim prior approval or an
established download reputation.

## Maintainer steps still required

- Supply a contact email directly to the signing provider, not in this public file.
- Confirm account ownership, enable required MFA and review the provider's terms.
- Confirm signing approvers and complete any requested project review.
- If accepted, authorize the provider's GitHub integration for this repository and
  configure its project, artifact definitions and manual production approval.

Only after approval should the public signing policy credit the actual provider.
Do not claim “signed,” “verified publisher,” or “SmartScreen-free” before verification.

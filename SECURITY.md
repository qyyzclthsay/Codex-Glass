# Security and privacy

Codex Glass is MIT-licensed open-source software. The current native widget contains
no developer telemetry, analytics SDK or developer data-collection endpoint. It does
not automatically send account details, usage, conversations or other personal data
to the maintainer. Information a user chooses to post in an issue is separate from
the application's behavior.

To function, the widget reads account identity (which can include an account ID or
email), plan, quota/reset information and token statistics through official Codex.
These responses are processed locally. Official Codex connects to OpenAI for account
queries and authentication; this statement about the widget does not describe or
override the official client's or OpenAI service's own data handling.

This project uses a locally installed official Codex runtime. Keep that runtime updated.
Authentication happens in the system browser through Codex's own login flow. The widget
does not receive your password, copy auth.json, store tokens, or run AI conversations.

The current app has native WPF controls and no browser engine, webpage renderer or web IPC.
Login URLs must be HTTPS on exact allowlisted official hosts; other external actions
use fixed official URLs. The Codex child process starts directly without a shell, with
hidden stdio, bounded reply buffers, request timeouts and EOF cleanup. It exits after
queries and after browser-login completion/cancel/timeout. Runtime settings and local
account data are never used as shell commands.

Daily token history is requested through Codex's official account usage method. Only
normalized dates and token counts are retained for display; per-thread response fields
are discarded. This feature does not scan session transcripts and does not write token
history to disk. Cached history and in-flight results are invalidated on account changes.

Local preferences, reminder state and cached quota data are not encrypted. They contain no credentials
but do contain usage and manually entered dates. Backend stderr is drained and discarded.
Account identifiers are hashed before persistence. These files should not be attached to
public issue reports. Screenshots can also disclose usage or membership information.

Please report reproducible security issues privately to the repository maintainer using
GitHub private vulnerability reporting if enabled. Do not post credentials, cookies,
tokens, account files, or raw service responses publicly. Until a maintainer contact is
configured, avoid submitting sensitive reproduction data in public issues.

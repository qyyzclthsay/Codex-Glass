# Security and privacy

This project uses a locally installed official Codex runtime. Keep that runtime updated.
Authentication happens in the system browser through Codex's own login flow. The widget
does not receive your password, copy auth.json, store tokens, or run AI conversations.

Version 0.4 has native WPF controls and no browser engine, webpage renderer or web IPC.
Login URLs must be HTTPS on exact allowlisted official hosts; other external actions
use fixed official URLs. The Codex child process starts directly without a shell, with
hidden stdio, bounded reply buffers, request timeouts and EOF cleanup. It exits after
queries and after browser-login completion/cancel/timeout. Runtime settings and local
account data are never used as shell commands.

Daily token history is requested through Codex's official account usage method. Only
normalized dates and token counts are retained for display; per-thread response fields
are discarded. This feature does not scan session transcripts and does not write token
history to disk. Cached history and in-flight results are invalidated on account changes.

Local preferences and cached quota data are not encrypted. They contain no credentials
but do contain usage and manually entered dates. Backend stderr is drained and discarded.
Account identifiers are hashed before persistence. These files should not be attached to
public issue reports. Screenshots can also disclose usage or membership information.

Please report reproducible security issues privately to the repository maintainer using
GitHub private vulnerability reporting if enabled. Do not post credentials, cookies,
tokens, account files, or raw service responses publicly. Until a maintainer contact is
configured, avoid submitting sensitive reproduction data in public issues.

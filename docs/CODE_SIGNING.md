# Code signing policy

**Status: v0.5.2 downloads are unsigned. No signing provider or Microsoft Store
listing has been approved for this project yet.** Adding this document and a
signature check does not change the existing downloads or remove SmartScreen.

## What the two prompts mean

- Edge's “not commonly downloaded” prompt concerns download reputation.
- Windows' “protected your PC / unknown publisher” prompt concerns application
  reputation and the absence of a trusted publisher signature.

Trusted signing identifies a publisher and protects file integrity. It does not
guarantee immediate SmartScreen reputation. Self-signed certificates do not solve
public distribution trust. See [Microsoft's explanation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation).

## Distribution routes

| Route | Required from the maintainer | Result and limits |
| --- | --- | --- |
| Free open-source signing application | Apply to SignPath Foundation; meet its project, account and review requirements | Subject to approval and verifiable project reputation; no promise of acceptance or immediate SmartScreen clearance |
| Existing trusted signing service or certificate | Verified publisher account and access to its signing process | Sign the application and installer, then accumulate reputation through legitimate distribution |
| Microsoft Store MSIX | Developer account, reserved product identity, compatible package and certification | Store signing after approval; an EXE-only Store submission still needs a trusted signature |

References: [SignPath requirements](https://signpath.org/terms.html),
[Microsoft Store submission](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/publish-first-app).

## Release signing sequence

1. Build and test one reviewed source revision on the approved build system.
2. Sign the application executable with a trusted production signing identity and
   SHA-256 / RFC 3161 timestamp. Preserve that exact signed executable for both the
   installer payload and portable distribution; rebuilding removes the signature.
3. Prepare the uninstaller signing step with the selected provider. The current
   NSIS script generates its uninstaller during compilation; signing only the outer
   installer will not sign that embedded executable.
4. Package the signed executable, then sign and timestamp the final installer.
5. Extract the installer into a disposable test directory. Verify its application
   matches the signed portable executable; verify all distributed executable signatures.
6. Create portable ZIPs and SHA-256 manifests from the final signed files. Publish a
   new release instead of silently replacing existing v0.5.2 assets.

The repository currently has an unsigned build workflow. Provider integration must
be completed after the signing service and identity are approved; this document is
not an enabled signing workflow.

## Signature verification

The read-only verification script requires a valid Windows-trusted signature and
a timestamp. Optionally require the exact certificate thumbprint supplied by the
approved signing provider:

```powershell
./scripts/verify-signatures.ps1 -Path @(
  'path/to/signed-application.exe',
  'path/to/signed-installer.exe'
) -ExpectedSignerThumbprint 'CERTIFICATE_THUMBPRINT_FROM_YOUR_PROVIDER'
```

Verification does not change certificate stores, disable SmartScreen or remove the
download-origin mark. It checks signature trust on the machine running the check;
it is not a SmartScreen reputation or malware certification.

## Responsibility

Maintainer, reviewer and release approver: [theSay / qyyzclthsay](https://github.com/qyyzclthsay).
Signing-provider credentials and private keys must never be committed to this repository.
The [privacy policy](../SECURITY.md) also documents the official Codex connection used by the app.

# Run after signing, before publishing. This script does not sign files or change trust settings.
param(
    [Parameter(Mandatory=$true)][string[]]$Path,
    [string]$ExpectedSignerThumbprint
)
$ErrorActionPreference = 'Stop'
if ($ExpectedSignerThumbprint -and $ExpectedSignerThumbprint -notmatch '^[0-9a-fA-F]{40}$') {
    throw 'ExpectedSignerThumbprint must be a 40-character certificate thumbprint.'
}
$results = @()
foreach ($item in $Path) {
    $file = Get-Item -LiteralPath $item
    if ($file.PSIsContainer -or $file.Extension -notin @('.exe','.dll','.msi','.msix','.appx')) {
        throw "Not a supported release binary: $item"
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
    if ($signature.Status -ne 'Valid' -or !$signature.SignerCertificate) {
        throw "Release signature is not trusted: $($file.Name) [$($signature.Status)]. Do not publish this as a signed build."
    }
    if (!$signature.TimeStamperCertificate) {
        throw "No signing timestamp: $($file.Name). Timestamp the release before publishing."
    }
    if ($ExpectedSignerThumbprint -and $signature.SignerCertificate.Thumbprint -ne $ExpectedSignerThumbprint) {
        throw "Unexpected signer: $($file.Name)"
    }
    $results += [pscustomobject]@{
        File = $file.Name
        Status = [string]$signature.Status
        Publisher = $signature.SignerCertificate.Subject
        SignerThumbprint = $signature.SignerCertificate.Thumbprint
        Timestamped = $true
        SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$results | ConvertTo-Json -Depth 3

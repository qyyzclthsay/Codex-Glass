param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
$glassRoot=Split-Path -Parent $PSScriptRoot
if(!$OutputDirectory){$OutputDirectory=Join-Path $glassRoot '.qa/native'}
$env:CODEX_GLASS_QA_DIR=$OutputDirectory
Remove-Item Env:CODEX_GLASS_DATA_DIR -ErrorAction SilentlyContinue
& (Join-Path $PSScriptRoot 'build-native.ps1') -Test
$glassQA=Start-Process -FilePath (Join-Path $glassRoot 'dist/native/Codex Glass.exe') -ArgumentList '--smoke-test' -WindowStyle Hidden -Wait -PassThru
if($glassQA.ExitCode -ne 0){throw "UI checks failed. See $OutputDirectory/error.txt"}
Get-Content -LiteralPath (Join-Path $OutputDirectory 'self-test.json'),(Join-Path $OutputDirectory 'ui-result.json')

param([switch]$Test,[switch]$Package)
$ErrorActionPreference = 'Stop'
$glassRoot = Split-Path -Parent $PSScriptRoot
$glassBuild = Join-Path $glassRoot 'build/native'
$glassDist = Join-Path $glassRoot 'dist/native'
New-Item -ItemType Directory -Force -Path $glassBuild,$glassDist | Out-Null
$glassFramework = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
$glassCompiler = Join-Path $glassFramework 'csc.exe'
if (!(Test-Path -LiteralPath $glassCompiler)) { throw 'Windows .NET Framework compiler not found.' }
# Resource generation has no network or package-manager dependency.
$glassLanguage = Get-Content -LiteralPath (Join-Path $glassRoot 'native/messages.json') -Raw -Encoding UTF8
[IO.File]::WriteAllText((Join-Path $glassBuild 'messages.json'),$glassLanguage,[Text.UTF8Encoding]::new($false))
[xml]$glassSvg = Get-Content -LiteralPath (Join-Path $glassRoot 'assets/openai.svg') -Raw -Encoding UTF8
[IO.File]::WriteAllText((Join-Path $glassBuild 'logo.txt'),$glassSvg.svg.path.d,[Text.UTF8Encoding]::new($false))
$glassRefs = @('System.dll','System.Core.dll','System.Web.Extensions.dll','System.Xaml.dll','WPF/WindowsBase.dll','System.Drawing.dll','System.Windows.Forms.dll','WPF/PresentationCore.dll','WPF/PresentationFramework.dll') | ForEach-Object { '/reference:' + (Join-Path $glassFramework $_) }
$glassSources = Get-ChildItem -LiteralPath (Join-Path $glassRoot 'native') -Filter '*.cs' | ForEach-Object FullName
$glassOutput = Join-Path $glassDist 'Codex Glass.exe'
& $glassCompiler /nologo /utf8output /target:winexe /platform:x64 /optimize+ /langversion:5 "/out:$glassOutput" "/win32manifest:$glassRoot/native/app.manifest" "/win32icon:$glassRoot/native/icon.ico" "/resource:$glassRoot/assets/icon.png,icon.png" "/resource:$glassRoot/native/icon.ico,icon.ico" "/resource:$glassBuild/messages.json,messages.json" "/resource:$glassBuild/logo.txt,logo.txt" "/resource:$glassRoot/native/styles.xaml,styles.xaml" "/resource:$glassRoot/LICENSE,LICENSE" "/resource:$glassRoot/THIRD_PARTY_NOTICES.md,NOTICES" "/resource:$glassRoot/licenses/Pulse-Apache-2.0.txt,APACHE" $glassRefs $glassSources
if($LASTEXITCODE -ne 0) { throw 'Native compilation failed.' }
Copy-Item -LiteralPath $glassOutput -Destination (Join-Path $glassRoot 'dist/Codex-Glass-0.5.2-Portable-x64.exe')
if($Test) {
    $glassRun = Start-Process -FilePath $glassOutput -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru
    if($glassRun.ExitCode -ne 0) { throw 'Native core tests failed. See CODEX_GLASS_QA_DIR/self-test-error.txt.' }
}
Get-Item -LiteralPath $glassOutput | Select-Object Name,Length
if($Package) {
    $glassNsis = $env:CODEX_GLASS_NSIS_PATH
    if(!$glassNsis) { $glassNsis = Join-Path ${env:ProgramFiles(x86)} 'NSIS/makensis.exe' }
    if(!(Test-Path -LiteralPath $glassNsis)) { throw 'Install NSIS or set CODEX_GLASS_NSIS_PATH to makensis.exe.' }
    Push-Location (Join-Path $glassRoot 'native')
    try { & $glassNsis /V2 installer.nsi; if($LASTEXITCODE -ne 0) { throw 'Installer build failed.' } } finally { Pop-Location }
    $glassPackage = Join-Path $glassBuild 'package'
    New-Item -ItemType Directory -Force -Path $glassPackage,(Join-Path $glassPackage 'licenses') | Out-Null
    Copy-Item -LiteralPath $glassOutput -Destination $glassPackage
    Copy-Item -LiteralPath (Join-Path $glassRoot 'LICENSE'),(Join-Path $glassRoot 'THIRD_PARTY_NOTICES.md') -Destination $glassPackage
    Copy-Item -LiteralPath (Join-Path $glassRoot 'licenses/Pulse-Apache-2.0.txt') -Destination (Join-Path $glassPackage 'licenses')
    Compress-Archive -Path (Join-Path $glassPackage '*') -DestinationPath (Join-Path $glassRoot 'dist/Codex-Glass-0.5.2-Portable-x64.zip') -Force
}

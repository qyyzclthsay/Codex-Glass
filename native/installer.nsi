Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"
Var ExtractOnly
Name "Codex Glass"
OutFile "..\dist\Codex-Glass-0.5.1-Setup-x64.exe"
InstallDir "$LOCALAPPDATA\Programs\Codex Glass Native"
InstallDirRegKey HKCU "Software\CodexGlassNative" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "Codex Glass 0.5.1 · Native Windows"
!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "TradChinese"
!insertmacro MUI_LANGUAGE "English"
Function .onInit
  ${GetParameters} $0
  ClearErrors
  ${GetOptions} $0 "/EXTRACTONLY" $1
  IfErrors normal
  StrCpy $ExtractOnly 1
  Return
  normal:
  !insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd
Section "Codex Glass"
  SetOutPath "$INSTDIR"
  File "..\dist\native\Codex Glass.exe"
  File "..\LICENSE"
  File "..\THIRD_PARTY_NOTICES.md"
  SetOutPath "$INSTDIR\licenses"
  File "..\licenses\Pulse-Apache-2.0.txt"
  SetOutPath "$INSTDIR"
  StrCmp $ExtractOnly 1 done
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\Codex Glass.lnk" "$INSTDIR\Codex Glass.exe"
  CreateDirectory "$SMPROGRAMS\Codex Glass"
  CreateShortcut "$SMPROGRAMS\Codex Glass\Codex Glass.lnk" "$INSTDIR\Codex Glass.exe"
  CreateShortcut "$SMPROGRAMS\Codex Glass\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\CodexGlassNative" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexGlassNative" "DisplayName" "Codex Glass"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexGlassNative" "DisplayVersion" "0.5.1"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexGlassNative" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexGlassNative" "DisplayIcon" "$INSTDIR\Codex Glass.exe"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexGlassNative" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexGlassNative" "NoRepair" 1
  done:
SectionEnd
Section "Uninstall"
  ; Remove only this installation's named files; preserve account preferences.
  Delete "$INSTDIR\Codex Glass.exe"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\THIRD_PARTY_NOTICES.md"
  Delete "$INSTDIR\licenses\Pulse-Apache-2.0.txt"
  RMDir "$INSTDIR\licenses"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$DESKTOP\Codex Glass.lnk"
  Delete "$SMPROGRAMS\Codex Glass\Codex Glass.lnk"
  Delete "$SMPROGRAMS\Codex Glass\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Codex Glass"
  ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Codex Glass"
  StrCmp $0 '"$INSTDIR\Codex Glass.exe" --hidden' 0 +2
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Codex Glass"
  DeleteRegKey HKCU "Software\CodexGlassNative"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CodexGlassNative"
SectionEnd

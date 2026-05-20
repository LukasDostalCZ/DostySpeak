!include "MUI2.nsh"
!include "FileFunc.nsh"
!insertmacro GetSize

!ifndef SOURCE_DIR
  !error "SOURCE_DIR is not defined. Pass /DSOURCE_DIR=path-to-deployed-folder"
!endif

!ifndef OUTPUT_EXE
  !define OUTPUT_EXE "DostySpeak-Setup-x64.exe"
!endif

!ifndef LICENSE_FILE
  !define LICENSE_FILE "LICENSE"
!endif

!ifndef INSTALL_DIR
  !define INSTALL_DIR "$PROGRAMFILES64\Dosty Speak"
!endif

!ifndef DISPLAY_ARCH
  !define DISPLAY_ARCH "x64"
!endif

!ifndef DEFAULT_INSTALL_DIR
  !define DEFAULT_INSTALL_DIR "$PROGRAMFILES64\Dosty Speak"
!endif

!define APP_NAME "Dosty Speak"
!define APP_EXE "dosty-speak.exe"
!define APP_VERSION "0.2.24"
!define APP_PUBLISHER "Lukáš Dostál"
!define APP_REGKEY "Software\Dosty Speak"
!define APP_UNINSTALL_REGKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dosty Speak"

Name "${APP_NAME}"
OutFile "${OUTPUT_EXE}"
InstallDir "${DEFAULT_INSTALL_DIR}"
InstallDirRegKey HKLM "${APP_REGKEY}" "InstallDir"
RequestExecutionLevel admin
Unicode true

VIProductVersion "0.2.24.0"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey "LegalCopyright" "Copyright (c) 2026 Lukáš Dostál"
VIAddVersionKey "FileDescription" "${APP_NAME} ${DISPLAY_ARCH} Installer"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"

BrandingText "${APP_NAME}"

!define MUI_ABORTWARNING
!define MUI_ICON "..\..\resources\icons\dosty-speak.ico"
!define MUI_UNICON "..\..\resources\icons\dosty-speak.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Dosty Speak"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${LICENSE_FILE}"
!insertmacro MUI_PAGE_DIRECTORY

!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_COMPONENTS

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_COMPONENTS
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Function CloseRunningDostySpeak
  DetailPrint "Closing running Dosty Speak instances..."
  nsExec::ExecToLog 'taskkill /F /T /IM dosty-speak.exe'
  nsExec::ExecToLog 'taskkill /F /T /IM dosty-speak-legacy-win32.exe'
  Sleep 1000
FunctionEnd


Section "Dosty Speak program files" SecProgram
  SectionIn RO

  SetOverwrite on
  Call CloseRunningDostySpeak

  SetOutPath "$INSTDIR"

  ; Clean previous program files while keeping user profile data.
  RMDir /r /REBOOTOK "$INSTDIR"

  SetOutPath "$INSTDIR"
  Delete /REBOOTOK "$INSTDIR\dosty-speak.exe"
  Delete /REBOOTOK "$INSTDIR\Qt6Core.dll"
  Delete /REBOOTOK "$INSTDIR\Qt6Gui.dll"
  Delete /REBOOTOK "$INSTDIR\Qt6Widgets.dll"
  Delete /REBOOTOK "$INSTDIR\Qt6Network.dll"
  Delete /REBOOTOK "$INSTDIR\Qt5Core.dll"
  Delete /REBOOTOK "$INSTDIR\Qt5Gui.dll"
  Delete /REBOOTOK "$INSTDIR\Qt5Widgets.dll"
  Delete /REBOOTOK "$INSTDIR\Qt5Network.dll"
  Delete /REBOOTOK "$INSTDIR\libgcc_s_seh-1.dll"
  Delete /REBOOTOK "$INSTDIR\libstdc++-6.dll"
  Delete /REBOOTOK "$INSTDIR\libwinpthread-1.dll"
  Delete /REBOOTOK "$INSTDIR\D3Dcompiler_47.dll"

  File /r "${SOURCE_DIR}\*.*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\Dosty Speak"
  CreateShortCut "$SMPROGRAMS\Dosty Speak\Dosty Speak.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$SMPROGRAMS\Dosty Speak\Uninstall Dosty Speak.lnk" "$INSTDIR\Uninstall.exe" "" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKLM "${APP_REGKEY}" "InstallDir" "$INSTDIR"

  WriteRegStr HKLM "${APP_UNINSTALL_REGKEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "${APP_UNINSTALL_REGKEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${APP_UNINSTALL_REGKEY}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "${APP_UNINSTALL_REGKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${APP_UNINSTALL_REGKEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKLM "${APP_UNINSTALL_REGKEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "${APP_UNINSTALL_REGKEY}" "QuietUninstallString" "$INSTDIR\Uninstall.exe /S"
  WriteRegDWORD HKLM "${APP_UNINSTALL_REGKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${APP_UNINSTALL_REGKEY}" "NoRepair" 1

  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKLM "${APP_UNINSTALL_REGKEY}" "EstimatedSize" $0
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortCut "$DESKTOP\Dosty Speak.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}"
SectionEnd

Section "Uninstall"
  Call CloseRunningDostySpeak
  Delete "$DESKTOP\Dosty Speak.lnk"
  Delete "$SMPROGRAMS\Dosty Speak\Dosty Speak.lnk"
  Delete "$SMPROGRAMS\Dosty Speak\Uninstall Dosty Speak.lnk"
  RMDir "$SMPROGRAMS\Dosty Speak"

  RMDir /r /REBOOTOK "$INSTDIR"

  DeleteRegKey HKLM "${APP_UNINSTALL_REGKEY}"
  DeleteRegKey HKLM "${APP_REGKEY}"
SectionEnd

Section /o "Remove user data, downloaded voices and bundled runtime" SecRemoveData
  RMDir /r "$APPDATA\Dosty\DostySpeak"
  RMDir /r "$LOCALAPPDATA\Dosty\DostySpeak"
SectionEnd

LangString DESC_SecProgram ${LANG_ENGLISH} "Install Dosty Speak program files into Program Files."
LangString DESC_SecDesktop ${LANG_ENGLISH} "Create a desktop shortcut."
LangString DESC_SecRemoveData ${LANG_ENGLISH} "Also delete settings, phrases, downloaded Piper voices and bundled runtime from your user profile."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecProgram} $(DESC_SecProgram)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} $(DESC_SecDesktop)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecRemoveData} $(DESC_SecRemoveData)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

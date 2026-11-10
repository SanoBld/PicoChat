; PicoChat Windows installer script (Inno Setup)
; Compiled by the CI workflow — see .github/workflows/build-windows.yml
;
; Usage: ISCC.exe windows\installer.iss /DMyArch=x64   (or arm64)
;        with env var APP_VERSION set (e.g. "2.7.0")
;
; NOTE: assumes the built exe is named "PicoChat.exe" (from the
; pubspec.yaml project name). If the actual exe has a different name,
; update MyAppExeName below.

#define MyAppExeName "PicoChat.exe"
#define MyAppVersion GetEnv("APP_VERSION")
#ifndef MyArch
  #define MyArch "x64"
#endif

[Setup]
; UNIQUE to PicoChat. Inno Setup uses this id to recognise an existing install: the old
; placeholder id was the same as another app (LastStats), so the installer replaced that app.
; NEVER reuse or change this id again.
AppId={{45FD41E5-7804-4F29-B36C-5C8B95DDEA9E}
AppName=PicoChat
AppVersion={#MyAppVersion}
AppPublisher=SanoBld
AppPublisherURL=https://github.com/SanoBld/PicoChat
DefaultDirName={autopf}\PicoChat
DefaultGroupName=PicoChat
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputBaseFilename=PicoChat-Setup-{#MyArch}
OutputDir=installer_output
Compression=lzma
SolidCompression=yes
SetupIconFile=runner\resources\app_icon.ico
WizardStyle=modern
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
CloseApplications=yes
RestartApplications=yes
#if MyArch == "arm64"
ArchitecturesInstallIn64BitMode=arm64
ArchitecturesAllowed=arm64
#else
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
#endif

[Languages]
Name: "english";           MessagesFile: "compiler:Default.isl"
Name: "french";            MessagesFile: "compiler:Languages\French.isl"
Name: "spanish";           MessagesFile: "compiler:Languages\Spanish.isl"
Name: "german";            MessagesFile: "compiler:Languages\German.isl"
Name: "italian";           MessagesFile: "compiler:Languages\Italian.isl"
Name: "portuguese";        MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "japanese";          MessagesFile: "compiler:Languages\Japanese.isl"
Name: "russian";           MessagesFile: "compiler:Languages\Russian.isl"
Name: "arabic";            MessagesFile: "compiler:Languages\Arabic.isl"
; Chinese (Simplified) is NOT bundled with Inno Setup and has no reliably
; reachable official download URL — left out rather than risk another
; broken build. Can be added later with a verified source if needed.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\{#MyArch}\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\PicoChat"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,PicoChat}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\PicoChat"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,PicoChat}"; Flags: nowait postinstall skipifsilent

[Code]
// Safety net: never install into the folder of another application.
function NextButtonClick(CurPageID: Integer): Boolean;
var
  Dir: String;
begin
  Result := True;
  if CurPageID = wpSelectDir then
  begin
    Dir := WizardDirValue;
    if FileExists(AddBackslash(Dir) + 'LastStats.exe') or
       (FileExists(AddBackslash(Dir) + 'unins000.exe') and not FileExists(AddBackslash(Dir) + '{#MyAppExeName}')) then
    begin
      MsgBox('This folder already contains another application. Please choose an empty folder or keep the default one.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

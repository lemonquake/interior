; Inno Setup 6 script for the Windows installer of Sleep (builds/windows/Interior.exe).
; Built by tools/build_installer.py, which passes AppVersion, SourceDir and OutputDir:
;   ISCC /DAppVersion=0.42.0 /DSourceDir=...\builds\windows /DOutputDir=...\builds\installer Sleep.iss
; Installs per user (no admin prompt) under %LOCALAPPDATA%\Programs\Sleep unless the player picks
; "install for all users" in the first dialog.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\builds\windows"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\builds\installer"
#endif

[Setup]
AppId={{6F4B2D7E-9C1A-4E5B-8F3D-2A7C9E1B5D40}
AppName=Sleep
AppVersion={#AppVersion}
AppVerName=Sleep {#AppVersion}
AppPublisher=Aljay Leodones
AppCopyright=Aljay Leodones
VersionInfoVersion={#AppVersion}
VersionInfoDescription=Sleep {#AppVersion} Setup
DefaultDirName={autopf}\Sleep
DefaultGroupName=Sleep
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=Sleep-{#AppVersion}-Setup
UninstallDisplayIcon={app}\Interior.exe
UninstallDisplayName=Sleep
Compression=lzma2/normal
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=8
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\Interior.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Sleep"; Filename: "{app}\Interior.exe"; WorkingDir: "{app}"
Name: "{autoprograms}\Uninstall Sleep"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Sleep"; Filename: "{app}\Interior.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Interior.exe"; Description: "{cm:LaunchProgram,Sleep}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

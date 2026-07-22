; velox.iss — Velox / Global Fast Windows 安装包(Inno Setup 6.x)
;
; 前置: 已执行 flutter build windows --release
;       产物存在于 build\windows\x64\runner\Release\
;
; 编译:
;   ISCC.exe /DAppVersion=1.0.11 installer\velox.iss
;
; 中文界面依赖 Languages\ChineseSimplified.isl(Inno Setup 6 官方发行版自带,
; choco install innosetup 装的也一般已带;若缺失见 CI workflow 里的 fallback。)

#ifndef AppVersion
  #define AppVersion "1.0.11"
#endif
#define AppName        "Velox"
#define AppExeName     "velox.exe"
#define AppPublisher   "Global Fast"
#define AppURL         "https://globalfast.example.com"
#define SourceDir      "..\build\windows\x64\runner\Release"

[Setup]
; 稳定 GUID —— 首版发布后永远不改,决定升级/卸载识别
AppId={{2AEC8FA5-D908-4C59-8546-C29471E1F690}}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename={#AppName}-{#AppVersion}-windows-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
WizardStyle=modern
; TUN 模式需要写 Program Files + 装驱动,只支持管理员安装
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName} {#AppVersion}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
MinVersion=10.0.17763
; 升级时先关旧进程,避免文件占用
CloseApplications=force
RestartApplications=no

[Languages]
; English 放前面作为 fallback（安装向导会让用户选语言）
Name: "english";    MessagesFile: "compiler:Default.isl"
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式(&D)"; GroupDescription: "附加图标:"
Name: "autostart";   Description: "开机自动启动 {#AppName}(&A)"; GroupDescription: "其他:"; Flags: unchecked

[Files]
; 主程序 + 所有 dll/exe(含 mihomo.exe / wintun.dll / 各插件 dll)
Source: "{#SourceDir}\*.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
; Flutter 资源目录(data\flutter_assets, data\icudtl.dat, data\app.so 等)
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}";              Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\卸载 {#AppName}";         Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";        Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; 开机启动(可选任务)—— 直接启动 velox.exe,不传参数
; (若日后 Dart 层支持 --minimized 等启动开关,可在此追加)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
  ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#AppExeName}"""; \
  Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#AppExeName}"; Description: "立即启动 {#AppName}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data\flutter_assets"
Type: dirifempty;     Name: "{app}\data"
Type: dirifempty;     Name: "{app}"

[Code]
// 卸载时询问是否清理用户配置(%APPDATA%\Velox)
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ConfigDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    ConfigDir := ExpandConstant('{userappdata}\{#AppName}');
    if DirExists(ConfigDir) then
    begin
      if MsgBox('是否同时删除用户配置目录?' + #13#10 + ConfigDir,
                mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
        DelTree(ConfigDir, True, True, True);
    end;
  end;
end;

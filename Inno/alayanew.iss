#include <D:\Program Files (x86)\Inno Download Plugin\idp.iss>

;------------------------------------------------------------------------------
; 基本信息设置
;------------------------------------------------------------------------------
#define MyAppName "AlayaNeWTools"
#define MyAppVersion "1.0.5"
#define MyAppPublisher "北京九章云极科技有限公司"
#define MyAppURL "https://www.alayanew.com"
#define MyAppExeName "AlayaNeWTools.exe"


;------------------------------------------------------------------------------
; 安装程序设置
;------------------------------------------------------------------------------
[Setup]
AppId={{GUID-生成一个唯一ID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\AlayaNewTools
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=Output
OutputBaseFilename=AlayaNeWTools
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
DisableDirPage=no
WizardSmallImageFile=D:/exe/123.bmp
WizardImageFile=D:/exe/大.bmp
SetupIconFile=D:/exe/favicon.ico
VersionInfoVersion={#MyAppVersion}

;------------------------------------------------------------------------------
; 语言设置
;------------------------------------------------------------------------------
[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

;------------------------------------------------------------------------------
; 文件设置
;------------------------------------------------------------------------------
[Files]
Source: "D:\exe\kubectl.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\exe\helm.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\exe\devtron\*"; DestDir: "{app}\devtron"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "D:\exe\favicon.ico"; DestDir: "{app}"; DestName: "app_icon.ico"; Flags: ignoreversion

;------------------------------------------------------------------------------
; 快捷方式设置
;------------------------------------------------------------------------------
[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\Devtron控制台"; Filename: "{app}\devtron_launcher.bat"; IconFilename: "{app}\app_icon.ico"; IconIndex: 0; Comment: "启动Devtron控制台"; WorkingDir: "{app}"

;------------------------------------------------------------------------------
; 代码部分
;------------------------------------------------------------------------------
[Code]
var
  KubeconfigPage: TInputFileWizardPage;
  DevtronUrl: string;
  DevtronPassword: string;

//------------------------------------------------------------------------------
// UI 相关函数
//------------------------------------------------------------------------------

// 创建自定义页面
procedure InitializeWizard;
begin
  KubeconfigPage := CreateInputFilePage(wpSelectDir,
    '选择Kubeconfig文件',
    '请选择您的Kubeconfig文件，该文件将被配置为环境变量。此步骤是必需的。',
    '选择文件:');
  KubeconfigPage.Add('Kubeconfig文件 (必需):', 'JSON files|*.json|YAML files|*.yaml|YML files|*.yml|All files|*.*', '.json');
end;

// 验证用户是否选择了文件
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = KubeconfigPage.ID then
  begin
    if (KubeconfigPage.Values[0] = '') or (not FileExists(KubeconfigPage.Values[0])) then
    begin
      MsgBox('请选择有效的Kubeconfig文件。此步骤是必需的，无法继续安装。', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

//------------------------------------------------------------------------------
// 文件和环境变量处理函数
//------------------------------------------------------------------------------

// Base64解码文件
function Base64DecodeFile(const InputFile, OutputFile: string): Boolean;
var
  ResultCode: Integer;
  TempOutputFile: string;
begin
  Result := False;
  TempOutputFile := ExpandConstant('{app}\kubeconfig_temp');

  Log('执行Base64解码: ' + InputFile);

  if not Exec('certutil.exe', '-decode "' + InputFile + '" "' + TempOutputFile + '"',
              '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Log('certutil命令执行失败，错误码: ' + IntToStr(ResultCode));
    MsgBox('无法执行certutil命令，请确认是否安装了证书工具。', mbError, MB_OK);
    Exit;
  end;

  if ResultCode <> 0 then
  begin
    Log('解码失败，返回码: ' + IntToStr(ResultCode));
    MsgBox('文件解码失败，可能不是有效的Base64格式。', mbError, MB_OK);
    Exit;
  end;

  if not FileExists(TempOutputFile) then
  begin
    Log('解码后文件不存在');
    MsgBox('解码后的文件未创建。', mbError, MB_OK);
    Exit;
  end;

  if not FileCopy(TempOutputFile, OutputFile, False) then
  begin
    Log('无法复制文件到目标位置');
    MsgBox('无法将解码后的文件复制到目标位置。', mbError, MB_OK);
    Exit;
  end;

  DeleteFile(TempOutputFile);
  Result := True;
  Log('文件解码成功: ' + OutputFile);
end;

// 添加到系统PATH环境变量
procedure AddToSystemPathEnvironmentVariable(const Value: string);
var
  CurrentPath, NewPath: string;
begin
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', CurrentPath) then
  begin
    if Pos(LowerCase(Value), LowerCase(CurrentPath)) = 0 then
    begin
      if (Length(CurrentPath) > 0) and (CurrentPath[Length(CurrentPath)] <> ';') then
        CurrentPath := CurrentPath + ';';

      NewPath := CurrentPath + Value;

      if not RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', NewPath) then
        Log('无法更新PATH环境变量');
    end;
  end else begin
    if not RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', Value) then
      Log('无法创建PATH环境变量');
  end;
end;

// 设置系统环境变量
procedure SetSystemEnvironmentVariable(const Name, Value: string);
begin
  if not RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', Name, Value) then
    Log('无法设置环境变量: ' + Name);
end;

// 确保kubeconfig配置生效
function EnsureKubeconfigWorks(const KubeconfigPath: string): Boolean;
var
  ResultCode: Integer;
  TempBatchFile: string;
begin
  Result := False;
  TempBatchFile := ExpandConstant('{app}\ensure_kubeconfig.bat');

  SaveStringToFile(TempBatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +
    'set KUBECONFIG=' + KubeconfigPath + #13#10 +
    'setx KUBECONFIG "' + KubeconfigPath + '" /M > nul' + #13#10 +
    '"' + ExpandConstant('{app}\kubectl.exe') + '" config view > "' + ExpandConstant('{app}\kubectl_config_test.txt') + '" 2>&1' + #13#10,
    False);

  Result := Exec(ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  DeleteFile(TempBatchFile);
  DeleteFile(ExpandConstant('{app}\kubectl_config_test.txt'));
end;

//------------------------------------------------------------------------------
// 命令执行和输出处理函数
//------------------------------------------------------------------------------

// 执行命令并获取输出
function ExecAndGetOutput(const Command, Params: string): string;
var
  OutputFile, BatchFile: string;
  ResultCode: Integer;
  Output: AnsiString;
begin
  Result := '';
  OutputFile := ExpandConstant('{app}\cmd_output.txt');
  BatchFile := ExpandConstant('{app}\run_cmd.bat');

  // 创建批处理文件
  SaveStringToFile(BatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +
    '"' + Command + '" ' + Params + ' > "' + OutputFile + '" 2>&1' + #13#10,
    False);

  // 执行批处理
  if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Sleep(2000); // 等待文件写入完成

    if FileExists(OutputFile) and LoadStringFromFile(OutputFile, Output) then
      Result := Output;
  end;

  // 清理文件
  DeleteFile(BatchFile);
  DeleteFile(OutputFile);
end;

// 从输出中提取Devtron URL
function ExtractDevtronUrl(const Output: string): string;
var
  UrlPos, UrlEnd: Integer;
  SearchStrings: array[0..2] of string;
  i: Integer;
begin
  Result := '';

  // 定义可能的搜索字符串
  SearchStrings[0] := 'IngressRoute successfully updated, url: https://';
  SearchStrings[1] := 'url: https://';
  SearchStrings[2] := 'https://';

  // 尝试每个搜索字符串
  for i := 0 to 2 do
  begin
    UrlPos := Pos(SearchStrings[i], Output);
    if UrlPos > 0 then
    begin
      // 调整位置到https://开始处
      UrlPos := UrlPos + Length(SearchStrings[i]) - Length('https://');

      // 查找URL结束位置
      UrlEnd := Pos(' ', Copy(Output, UrlPos, Length(Output)));
      if UrlEnd = 0 then UrlEnd := Pos(#13, Copy(Output, UrlPos, Length(Output)));
      if UrlEnd = 0 then UrlEnd := Pos(#10, Copy(Output, UrlPos, Length(Output)));

      if UrlEnd = 0 then
        UrlEnd := Length(Output) - UrlPos + 1
      else
        UrlEnd := UrlEnd - 1;

      // 提取URL
      Result := Copy(Output, UrlPos, UrlEnd);

      // 添加端口号
      if Pos(':', Result) = 0 then
        Result := Result + ':22443';

      Log('提取到URL: ' + Result);
      Break;
    end;
  end;

  if Result = '' then
    Log('未能从输出中找到URL');
end;

//------------------------------------------------------------------------------
// Devtron相关函数
//------------------------------------------------------------------------------

// 获取Devtron管理员密码
function GetDevtronAdminPassword: string;
var
  BatchFile, TempInputFile, TempOutputFile: string;
  ResultCode: Integer;
  OutputContent: AnsiString;
  LogFileAdmin: string;
begin
  Result := '';
  TempInputFile := ExpandConstant('{app}\admin_pwd_input.txt');
  TempOutputFile := ExpandConstant('{app}\admin_pwd_output.txt');
  BatchFile := ExpandConstant('{app}\get_admin_pwd.bat');
  LogFileAdmin := ExpandConstant('{app}\adminPassword.log');

  // 创建批处理文件
  SaveStringToFile(BatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +
    'set KUBECONFIG=' + ExpandConstant('{app}\kubeconfig') + #13#10 +
    '"' + ExpandConstant('{app}\kubectl.exe') + '" -n devtroncd get secret devtron-secret -o jsonpath="{.data.ADMIN_PASSWORD}" > "' + TempInputFile + '" 2>&1' + #13#10 +
    'if exist "' + TempInputFile + '" (' + #13#10 +
    '  certutil -decode "' + TempInputFile + '" "' + TempOutputFile + '" > nul' + #13#10 +
    ')' + #13#10,
    False);

  // 执行批处理
  if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    // 尝试读取密码
    if FileExists(TempOutputFile) and LoadStringFromFile(TempOutputFile, OutputContent) then
      Result := Trim(OutputContent)
    else if FileExists(TempInputFile) and LoadStringFromFile(TempInputFile, OutputContent) then
    begin
      // 尝试使用PowerShell解码
      SaveStringToFile(BatchFile,
        '@echo off' + #13#10 +
        'chcp 65001 > nul' + #13#10 +
        'powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(''' + Trim(OutputContent) + '''))" > "' + TempOutputFile + '"' + #13#10,
        False);

      if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
         FileExists(TempOutputFile) and LoadStringFromFile(TempOutputFile, OutputContent) then
        Result := Trim(OutputContent);
    end;
  end;

  // 清理临时文件
  DeleteFile(TempInputFile);
  DeleteFile(TempOutputFile);
  DeleteFile(BatchFile);
end;

// 创建Devtron启动脚本
procedure CreateDevtronLauncherScript;
var
  ScriptPath, ScriptContent: string;
begin
  ScriptPath := ExpandConstant('{app}\devtron_launcher.bat');

  ScriptContent :=
    '@echo off' + #13#10 +
    'echo 正在启动Devtron控制台...' + #13#10 +
    'start "" "' + Trim(DevtronUrl) + ':22443"' + #13#10 + // Trim 处理
    'echo.' + #13#10 +
    'echo Devtron控制台已启动' + #13#10 +
    'echo 访问地址: ' + Trim(DevtronUrl) + ':22443' + #13#10 +
    'echo 管理员账户: admin' + #13#10 +
    'echo 管理员密码: ' + DevtronPassword + #13#10 +
    'echo.' + #13#10 +
    'pause';

  SaveStringToFile(ScriptPath, ScriptContent, False);
end;

// 安装Devtron
function InstallDevtron: Boolean;
var
  LogFile, TempBatchFile, KubeconfigPath: string;
  ResultCode: Integer;
  Output: string;
  OutputContent: AnsiString;

   // 添加进度条相关变量
  WaitForm: TForm;
  ProgressBar: TNewProgressBar;
  StatusLabel: TNewStaticText;
  StartTime: DWORD;
  i, TotalSeconds: Integer;

begin
  Result := False;

  try
    LogFile := ExpandConstant('{app}\devtron_install.log');
    KubeconfigPath := ExpandConstant('{app}\kubeconfig');

    // 记录安装开始
    SaveStringToFile(LogFile, '开始安装Devtron: ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);

    // 创建安装批处理文件
    TempBatchFile := ExpandConstant('{app}\devtron_install.bat');
    SaveStringToFile(TempBatchFile,
      '@echo off' + #13#10 +
      'setlocal enabledelayedexpansion' + #13#10 +
      'chcp 65001 > nul' + #13#10 +
      'cd /d "' + ExpandConstant('{app}\devtron') + '"' + #13#10 +
      'set KUBECONFIG=' + KubeconfigPath + #13#10 +

      'echo 正在获取集群信息...' + #13#10 +
      '"' + ExpandConstant('{app}\kubectl.exe') + '" config view > config_view.txt 2>&1' + #13#10 +

      'set "server_url="' + #13#10 +
      'for /f "delims=" %%i in (''type config_view.txt ^| find "server:"'') do (' + #13#10 +
      '    set "line=%%i"' + #13#10 +
      '    for /f "tokens=1* delims= " %%a in ("!line!") do (' + #13#10 +
      '        if /i "%%a"=="server:" (' + #13#10 +
      '            set "server_url=%%b"' + #13#10 +
      '            goto :server_found' + #13#10 +
      '        )' + #13#10 +
      '    )' + #13#10 +
      ')' + #13#10 +

      ':server_found' + #13#10 +
      'if "!server_url!"=="" (' + #13#10 +
      '    echo Error: Missing server field in kubeconfig' + #13#10 +
      '    exit /b 1' + #13#10 +
      ')' + #13#10 +

      'echo 开始安装Devtron...' + #13#10 +

      '"' + ExpandConstant('{app}\kubectl.exe') + '" delete namespace devtroncd >> "' + LogFile + '.output" 2>&1' + #13#10 +
      '"' + ExpandConstant('{app}\helm.exe') + '" uninstall devtron --namespace devtroncd >> "' + LogFile + '.output" 2>&1' + #13#10 +

      'for /f "tokens=2 delims=." %%a in ("!server_url!") do set "zoneID=%%a"' + #13#10 +
      'for /f "tokens=4 delims=/" %%a in ("!server_url!") do set "vksID=%%a"' + #13#10 +

      'echo zoneID: !zoneID! >> "' + LogFile + '.output" 2>&1' + #13#10 +
      'echo vksID: !vksID! >> "' + LogFile + '.output" 2>&1' + #13#10 +

      '"' + ExpandConstant('{app}\helm.exe') + '" install devtron . --create-namespace -n devtroncd --values resources.yaml --set zoneID=!zoneID! --set vksID=!vksID! --set global.containerRegistry="registry.!zoneID!.alayanew.com:8443/vc-app_market/devtron" --timeout 300s >> "' + LogFile + '.output" 2>&1' + #13#10 +

      '"' + ExpandConstant('{app}\kubectl.exe') + '" create configmap devtron-global-config -n devtroncd --from-literal=vksID=!vksID! >> "' + LogFile + '.output" 2>&1' + #13#10,
      False);


    // 在执行安装命令之前添加进度条准备
    WizardForm.ProgressGauge.Style := npbstMarquee; // 使用动态进度条样式
    WizardForm.StatusLabel.Caption := '正在安装Devtron，需要2-3分钟，请耐心等待...';

    // 执行安装
    if not Exec(ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then

    begin
      Log('启动Devtron安装失败，错误码: ' + IntToStr(ResultCode));
      WizardForm.ProgressGauge.Style := npbstNormal;
      WizardForm.ProgressGauge.Position := 0;
      Exit;
    end;

    // 安装完成，设置进度条为100%
    WizardForm.ProgressGauge.Style := npbstNormal;
    WizardForm.ProgressGauge.Position := 100;
    WizardForm.StatusLabel.Caption := 'Devtron安装完成';



        // 使用WizardForm进度条替代自定义窗口
    WizardForm.StatusLabel.Caption := '正在启动Devtron服务，请耐心等待...';
    WizardForm.ProgressGauge.Min := 0;
    WizardForm.ProgressGauge.Max := 100;

    // 进度循环
    for i := 1 to 110 do
    begin
      // 更新进度条
      WizardForm.ProgressGauge.Position := i;

      // 更新状态文本
      WizardForm.StatusLabel.Caption := '正在启动Devtron服务，请耐心等待...' +
                                       IntToStr((i * 100) div 110) + '%';

      // 等待1秒
      Sleep(1000);
    end;

    // 获取Devtron URL
    TempBatchFile := ExpandConstant('{tmp}\get_devtron_url.bat');
    SaveStringToFile(TempBatchFile,
      '@echo off' + #13#10 +
      'chcp 65001 > nul' + #13#10 +
      'set KUBECONFIG=' + KubeconfigPath + #13#10 +
      '"' + ExpandConstant('{app}\kubectl.exe') + '" describe serviceexporter devtron-itf -n devtroncd > "' +
      ExpandConstant('{app}\devtron_url.txt') + '" 2>&1' + #13#10,
      False);

    if Exec(ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
       FileExists(ExpandConstant('{app}\devtron_url.txt')) and
       LoadStringFromFile(ExpandConstant('{app}\devtron_url.txt'), OutputContent) then
    begin
      DevtronUrl := ExtractDevtronUrl(OutputContent);
    end;

    if DevtronUrl = '' then
      MsgBox('无法获取Devtron URL，请检查Devtron是否正常运行。', mbError, MB_OK);

    // 获取管理员密码
    DevtronPassword := GetDevtronAdminPassword();

    // 如果无法获取密码，显示提示
    if DevtronPassword = '' then
    begin
      MsgBox('Devtron安装已完成。安装完成后，您可以通过桌面快捷方式访问Devtron控制台。Devtron 管理员密码。' + #13#10 +
            '您可以cmd窗口执行以下命令获取:' + #13#10 +
            'kubectl -n devtroncd get secret devtron-secret -o jsonpath=''{.data.ADMIN_PASSWORD}''  在进行 base64 解码',
            mbInformation, MB_OK);
    end;

    // 创建启动脚本
    CreateDevtronLauncherScript();

    MsgBox('Devtron安装已完成，您可以通过桌面快捷方式访问Devtron控制台。', mbInformation, MB_OK);

    Result := True;
  except
    // 记录通用错误信息
    Log('安装Devtron时发生错误');
    MsgBox('安装Devtron时发生错误，请检查日志了解详情。', mbError, MB_OK);
  end;

  // 清理临时文件
  DeleteFile(TempBatchFile);
end;

//------------------------------------------------------------------------------
// 安装事件处理
//------------------------------------------------------------------------------

// 安装后处理
procedure CurStepChanged(CurStep: TSetupStep);
var
  KubeconfigPath, DecodedFile, ToolsPath: string;
  DecodingSuccess: Boolean;
begin
  if CurStep = ssPostInstall then
  begin
    // 设置环境变量
    ToolsPath := ExpandConstant('{app}');
    AddToSystemPathEnvironmentVariable(ToolsPath);

    // 处理kubeconfig文件
    KubeconfigPath := KubeconfigPage.Values[0];
    DecodedFile := ExpandConstant('{app}\kubeconfig');

    // 解码kubeconfig
    DecodingSuccess := Base64DecodeFile(KubeconfigPath, DecodedFile);

    if DecodingSuccess then
    begin
      // 设置环境变量
      SetSystemEnvironmentVariable('KUBECONFIG', DecodedFile);

      // 确保配置生效
      if not EnsureKubeconfigWorks(DecodedFile) then
        MsgBox('KUBECONFIG环境变量已设置，但可能需要重启计算机才能完全生效。', mbInformation, MB_OK);

      // 安装Devtron
      InstallDevtron();
    end
    else
    begin
      MsgBox('KUBECONFIG解码失败，终止安装', mbError, MB_OK);
      Abort();
    end;
  end;
end;
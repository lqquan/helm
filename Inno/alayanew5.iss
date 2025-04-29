#include <D:\Program Files (x86)\Inno Download Plugin\idp.iss>

;------------------------------------------------------------------------------
; 基本信息设置
;------------------------------------------------------------------------------
#define MyAppName "AlayaNeWTools"
#define MyAppVersion "1.0.9"
#define MyAppPublisher "北京九章云极科技有限公司"
#define MyAppURL "https://www.alayanew.com"
#define MyAppExeName "AlayaNeWTools.exe"


;------------------------------------------------------------------------------
; 安装程序设置
;------------------------------------------------------------------------------
[Setup]
AppId={{722653DA-F9EC-4C26-9C8B-9D7961BD020B}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={pf}\AlayaNeWTools
ArchitecturesInstallIn64BitMode=x64
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=Output
OutputBaseFilename=AlayaNeWTools
DisableProgramGroupPage=yes
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
DisableDirPage=no
WizardSmallImageFile=D:/exe/123.bmp
WizardImageFile=D:/exe/big.bmp
SetupIconFile=D:/exe/favicon.ico
VersionInfoVersion={#MyAppVersion}
DefaultDialogFontName=Microsoft YaHei
UninstallDisplayIcon={app}\app_icon.ico

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
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
Source: "D:\exe\devtron\*"; DestDir: "{app}\devtron"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: ShouldCreateIcons
Source: "D:\exe\favicon.ico"; DestDir: "{app}"; DestName: "app_icon.ico"; Flags: ignoreversion

;------------------------------------------------------------------------------
; 快捷方式设置
;------------------------------------------------------------------------------
[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\devtron_launcher.bat"; IconFilename: "{app}\app_icon.ico"; IconIndex: 0; Comment: "启动Devtron控制台"; WorkingDir: "{app}"; Check: ShouldCreateIcons
Name: "{commondesktop}\Devtron控制台"; Filename: "{app}\devtron_launcher.bat"; IconFilename: "{app}\app_icon.ico"; IconIndex: 0; Comment: "启动Devtron控制台"; WorkingDir: "{app}"; Check: ShouldCreateIcons

;------------------------------------------------------------------------------
; 代码部分
;------------------------------------------------------------------------------
[Code]
var
  KubeconfigPage: TInputFileWizardPage;
  DevtronPage: TInputOptionWizardPage;  // 修正类型名称
  DevtronUrl: string;
  DevtronPassword: string;
  InstallTimer: TTimer;

// 前向声明
procedure ProcessInstallComplete; forward;
procedure UpdateServiceProgress(Sender: TObject); forward;

//------------------------------------------------------------------------------
// UI 相关函数
//------------------------------------------------------------------------------

// 创建自定义页面
procedure InitializeWizard;
begin
  // 创建Kubeconfig选择页面
  KubeconfigPage := CreateInputFilePage(wpSelectDir,
    '选择Kubeconfig文件',
    '请选择您的Kubeconfig文件，该文件将被配置为环境变量。此步骤是必需的。',
    '选择文件:');
  KubeconfigPage.Add('Kubeconfig文件 (必需):', 'JSON files|*.json|YAML files|*.yaml|YML files|*.yml|All files|*.*', '.json');

  // 创建Devtron安装选项页面
  DevtronPage := CreateInputOptionPage(KubeconfigPage.ID,
    '安装Devtron',
    '是否安装Devtron平台？',
    '选择是否安装Devtron平台。安装后将创建桌面快捷方式以访问Devtron控制台。' + #13#10 + #13#10 +
    '如果不安装，您仍然可以使用kubectl和helm工具来管理Kubernetes集群。',
    False, False);
  DevtronPage.Add('安装Devtron平台');
  DevtronPage.Values[0] := True; // 默认选中
end;

// 验证用户是否选择了文件
function NextButtonClick(CurPageID: Integer): Boolean;
var
  KubeconfigPath: string;
  TempOutputFile: string;
  ResultCode: Integer;
  LogFile: string;
  FileContent: AnsiString;
  IsValid: Boolean;
begin
  Result := True;

  if CurPageID = KubeconfigPage.ID then
  begin
    // 首先检查是否选择了文件
    if (KubeconfigPage.Values[0] = '') or (not FileExists(KubeconfigPage.Values[0])) then
    begin
      MsgBox('请选择有效的Kubeconfig文件。此步骤是必需的，无法继续安装。', mbError, MB_OK);
      Result := False;
      Exit;
    end;

    // 获取文件路径
    KubeconfigPath := KubeconfigPage.Values[0];
    LogFile := ExpandConstant('{app}\kubeconfig_verify.log');
    TempOutputFile := ExpandConstant('{app}\kubeconfig_temp');

    // 验证文件内容
    IsValid := False;

    // 尝试读取文件内容
    if LoadStringFromFile(KubeconfigPath, FileContent) then
    begin
      FileContent := Trim(FileContent);

      // 检查是否是JSON/YAML格式
      if ((Pos('{', FileContent) = 1) and (Pos('apiVersion', FileContent) > 0) and (Pos('kind', FileContent) > 0))  then
      begin
        // 看起来是合法的JSON/YAML格式
        IsValid := True;
      end
      else
      begin
        // 如果不是明显的JSON/YAML，尝试作为Base64解码
        WizardForm.StatusLabel.Caption := '正在验证Kubeconfig文件...';
        DeleteFile(TempOutputFile);
        if Exec('certutil.exe', '-decode "' + KubeconfigPath + '" "' + TempOutputFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then

        begin
          // 检查解码结果
          Log('CertUtil 执行结果代码: ' + IntToStr(ResultCode));
          if (ResultCode = 0) and FileExists(TempOutputFile) then

          begin
            // 读取解码后文件内容
            if LoadStringFromFile(TempOutputFile, FileContent) then
            begin
              FileContent := Trim(FileContent);
              Log('文件解码成功: ' + FileContent);
              // 再次检查是否是JSON/YAML格式
              if ((Pos('{', FileContent) = 1) and (Pos('apiVersion', FileContent) > 0) and (Pos('kind', FileContent) > 0))  then
              begin
                IsValid := True;
              end;
            end;
          end;
        end;
        // 清理临时文件
        DeleteFile(TempOutputFile);
      end;
    end;

    WizardForm.StatusLabel.Caption := '';

    if not IsValid then
    begin
      // 文件验证失败
      MsgBox('所选文件不是有效的Kubeconfig文件。请选择正确的文件后再继续。', mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end
  else if CurPageID = DevtronPage.ID then
  begin
    // 记录用户的选择，无需特别验证
    if DevtronPage.Values[0] then
      Log('用户选择安装Devtron: 是')
    else
      Log('用户选择安装Devtron: 否');
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
  LogFile: string;
  FileContent: AnsiString;
  IsJsonOrYaml: Boolean;
begin
  Result := False;
  LogFile := ExpandConstant('{app}\base64_decode.log');
  TempOutputFile := ExpandConstant('{app}\kubeconfig_temp');

  // 初始化日志
  SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
  SaveStringToFile(LogFile, '【开始】Base64解码文件 - ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);
  SaveStringToFile(LogFile, '【参数】输入文件: ' + InputFile + #13#10, True);
  SaveStringToFile(LogFile, '【参数】输出文件: ' + OutputFile + #13#10, True);

  Log('执行Base64解码: ' + InputFile);

  // 读取文件内容，检查是否已经是JSON/YAML格式
  if LoadStringFromFile(InputFile, FileContent) then
  begin
    FileContent := Trim(FileContent);
    IsJsonOrYaml := (Pos('{', FileContent) = 1) and
                   (Pos('apiVersion', FileContent) > 0) and
                   (Pos('kind', FileContent) > 0);

    if IsJsonOrYaml then
    begin
      // 文件已经是JSON/YAML格式，直接复制
      SaveStringToFile(LogFile, '【检测】文件内容已经是JSON/YAML格式，无需解码' + #13#10, True);
      // 先检查并删除目标文件（如果存在）
      if FileExists(OutputFile) then
      begin
        SaveStringToFile(LogFile, '【步骤】删除已存在的目标文件: ' + OutputFile + #13#10, True);
        if not DeleteFile(OutputFile) then
          SaveStringToFile(LogFile, '【警告】无法删除已存在的目标文件，将尝试覆盖' + #13#10, True);
      end;
      if FileCopy(InputFile, OutputFile, True) then
      begin
        Result := True;
        Log('文件已是JSON/YAML格式，已直接复制: ' + OutputFile);
        SaveStringToFile(LogFile, '【成功】文件已直接复制到目标位置' + #13#10, True);
        SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
        Exit;
      end else begin
        Log('无法复制文件到目标位置');
        SaveStringToFile(LogFile, '【错误】无法复制文件到目标位置: ' + OutputFile + #13#10, True);
        SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
        Exit;
      end;
    end;

    // 不是JSON/YAML格式，执行解码
    SaveStringToFile(LogFile, '【检测】文件可能是Base64编码，尝试解码' + #13#10, True);
  end;

  // 执行certutil命令进行解码
  SaveStringToFile(LogFile, '【执行】certutil解码命令' + #13#10, True);

  if not Exec('certutil.exe', '-decode "' + InputFile + '" "' + TempOutputFile + '"',
              '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Log('certutil命令执行失败');
    SaveStringToFile(LogFile, '【错误】certutil命令执行失败' + #13#10, True);
    Exit;
  end;

  // 检查解码结果
  if not FileExists(TempOutputFile) then
  begin
    Log('解码后文件不存在');
    SaveStringToFile(LogFile, '【错误】解码后文件不存在' + #13#10, True);
    Exit;
  end;

  if FileExists(OutputFile) then
      begin
        SaveStringToFile(LogFile, '【步骤1】删除已存在的目标文件: ' + OutputFile + #13#10, True);
        if not DeleteFile(OutputFile) then
          SaveStringToFile(LogFile, '【警告1】无法删除已存在的目标文件，将尝试覆盖' + #13#10, True);
      end;
  // 复制解码后的文件到目标位置
  if not FileCopy(TempOutputFile, OutputFile, True) then
  begin
    Log('无法复制文件到目标位置');
    SaveStringToFile(LogFile, '【错误】无法复制文件到目标位置' + #13#10, True);
    Exit;
  end;

  // 清理临时文件
  DeleteFile(TempOutputFile);

  // 解码成功
  Result := True;
  Log('文件解码成功: ' + OutputFile);
  SaveStringToFile(LogFile, '【成功】文件解码完成' + #13#10, True);
  SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
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
  LogFile: string;
begin
  Result := '';
  LogFile := ExpandConstant('{app}\url_extract.log');

  // 记录URL提取开始
  SaveStringToFile(LogFile, '==========================================' + #13#10, True);
  SaveStringToFile(LogFile, '【开始】提取Devtron URL - ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);

  // 记录输入内容的一部分（避免日志过大）
  if Length(Output) > 200 then
    SaveStringToFile(LogFile, '【输入】输入内容(前200字符): ' + Copy(Output, 1, 200) + '...' + #13#10, True)
  else
    SaveStringToFile(LogFile, '【输入】输入内容: ' + Output + #13#10, True);

  // 定义可能的搜索字符串（按优先级排序）
  SaveStringToFile(LogFile, '【处理】定义用于搜索URL的字符串模式' + #13#10, True);
  SearchStrings[0] := 'IngressRoute successfully updated, url: https://';
  SearchStrings[1] := 'url: https://';
  SearchStrings[2] := 'https://';

  // 尝试每个搜索字符串
  for i := 0 to 2 do
  begin
    SaveStringToFile(LogFile, '【搜索】尝试使用模式 [' + IntToStr(i) + ']: ' + SearchStrings[i] + #13#10, True);
    UrlPos := Pos(SearchStrings[i], Output);

    if UrlPos > 0 then
    begin
      SaveStringToFile(LogFile, '【匹配】在位置 ' + IntToStr(UrlPos) + ' 找到匹配' + #13#10, True);

      // 调整位置到https://开始处
      UrlPos := UrlPos + Length(SearchStrings[i]) - Length('https://');
      SaveStringToFile(LogFile, '【调整】URL起始位置调整为: ' + IntToStr(UrlPos) + #13#10, True);

      // 查找URL结束位置（使用多种可能的终止符）
      UrlEnd := Pos(' ', Copy(Output, UrlPos, Length(Output)));
      if UrlEnd = 0 then
      begin
        SaveStringToFile(LogFile, '【搜索】查找空格作为URL终止符未找到，尝试回车符' + #13#10, True);
        UrlEnd := Pos(#13, Copy(Output, UrlPos, Length(Output)));
      end;

      if UrlEnd = 0 then
      begin
        SaveStringToFile(LogFile, '【搜索】查找回车符作为URL终止符未找到，尝试换行符' + #13#10, True);
        UrlEnd := Pos(#10, Copy(Output, UrlPos, Length(Output)));
      end;

      if UrlEnd = 0 then
      begin
        SaveStringToFile(LogFile, '【搜索】未找到URL终止符，使用剩余全部文本作为URL' + #13#10, True);
        UrlEnd := Length(Output) - UrlPos + 1;
      end
      else
      begin
        SaveStringToFile(LogFile, '【搜索】找到URL终止符，位置为: ' + IntToStr(UrlEnd) + #13#10, True);
        UrlEnd := UrlEnd - 1;
      end;

      // 提取URL
      Result := Copy(Output, UrlPos, UrlEnd);
      SaveStringToFile(LogFile, '【提取】提取的URL: ' + Result + #13#10, True);

      // 检查并添加端口号（如果需要）
      if Pos(':', Result) = 0 then
      begin
        SaveStringToFile(LogFile, '【端口】URL中未包含端口号，添加默认端口22443' + #13#10, True);
        Result := Result + ':22443';
      end;

      SaveStringToFile(LogFile, '【结果】最终URL: ' + Result + #13#10, True);
      Break;
    end
    else
    begin
      SaveStringToFile(LogFile, '【结果】未找到匹配模式' + #13#10, True);
    end;
  end;

  if Result = '' then
  begin
    SaveStringToFile(LogFile, '【警告】未能从输出中找到URL' + #13#10, True);
    Log('未能从输出中找到URL');
  end;

  SaveStringToFile(LogFile, '【完成】URL提取处理完成' + #13#10, True);
  SaveStringToFile(LogFile, '==========================================' + #13#10, True);
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

  // 初始化文件路径
  TempInputFile := ExpandConstant('{app}\admin_pwd_input.txt');
  TempOutputFile := ExpandConstant('{app}\admin_pwd_output.txt');
  BatchFile := ExpandConstant('{app}\get_admin_pwd.bat');
  LogFileAdmin := ExpandConstant('{app}\adminPassword.log');

  // 记录操作日志
  SaveStringToFile(LogFileAdmin, '==========================================' + #13#10, True);
  SaveStringToFile(LogFileAdmin, '【开始】获取管理员密码 - ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);

  // 创建批处理文件
  SaveStringToFile(LogFileAdmin, '【步骤1】创建获取密码的批处理文件' + #13#10, True);
  SaveStringToFile(BatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +
    'echo [Time] ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + ' > "' + LogFileAdmin + '.output"' + #13#10 +
    'echo [Command] Starting to execute admin password retrieval command >> "' + LogFileAdmin + '.output"' + #13#10 +
    'set KUBECONFIG=' + ExpandConstant('{app}\kubeconfig') + #13#10 +
    'echo [Command] kubectl -n devtroncd get secret devtron-secret... >> "' + LogFileAdmin + '.output"' + #13#10 +
    '"' + ExpandConstant('{app}\kubectl.exe') + '" -n devtroncd get secret devtron-secret -o jsonpath="{.data.ADMIN_PASSWORD}" > "' + TempInputFile + '" 2>&1' + #13#10 +
    'if %ERRORLEVEL% NEQ 0 (' + #13#10 +
    '  echo [Error] Failed to execute kubectl command, error code: %ERRORLEVEL% >> "' + LogFileAdmin + '.output"' + #13#10 +
    '  exit /b %ERRORLEVEL%' + #13#10 +
    ')' + #13#10 +
    'if exist "' + TempInputFile + '" (' + #13#10 +
    '  echo [Command] Decoding password with base64 >> "' + LogFileAdmin + '.output"' + #13#10 +
    '  certutil -decode "' + TempInputFile + '" "' + TempOutputFile + '" > nul' + #13#10 +
    '  if %ERRORLEVEL% NEQ 0 (' + #13#10 +
    '    echo [Error] base64 decoding failed, attempting PowerShell decoding >> "' + LogFileAdmin + '.output"' + #13#10 +
    '  ) else (' + #13#10 +
    '    echo [Info] base64 decoding successful >> "' + LogFileAdmin + '.output"' + #13#10 +
    '  )' + #13#10 +
    ')' + #13#10 +
    'echo [Complete] Command execution finished >> "' + LogFileAdmin + '.output"' + #13#10,
    False);

  // 执行批处理
  SaveStringToFile(LogFileAdmin, '【步骤2】执行批处理文件' + #13#10, True);

  if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    SaveStringToFile(LogFileAdmin, '【步骤2】批处理执行完成，返回代码: ' + IntToStr(ResultCode) + #13#10, True);

    // 尝试读取密码
    if FileExists(TempOutputFile) and LoadStringFromFile(TempOutputFile, OutputContent) then
    begin
      Result := Trim(OutputContent);
      SaveStringToFile(LogFileAdmin, '【步骤3】从certutil解码后的文件读取密码成功' + #13#10, True);
    end
    else if FileExists(TempInputFile) and LoadStringFromFile(TempInputFile, OutputContent) then
    begin
      SaveStringToFile(LogFileAdmin, '【步骤3】certutil解码失败，尝试使用PowerShell解码' + #13#10, True);

      // 尝试使用PowerShell解码
      SaveStringToFile(BatchFile,
        '@echo off' + #13#10 +
        'chcp 65001 > nul' + #13#10 +
        'echo [命令] 使用PowerShell进行base64解码 >> "' + LogFileAdmin + '.output"' + #13#10 +
        'powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(''' + Trim(OutputContent) + '''))" > "' + TempOutputFile + '"' + #13#10 +
        'if %ERRORLEVEL% NEQ 0 (' + #13#10 +
        '  echo [错误] PowerShell解码失败，错误代码: %ERRORLEVEL% >> "' + LogFileAdmin + '.output"' + #13#10 +
        ') else (' + #13#10 +
        '  echo [信息] PowerShell解码成功 >> "' + LogFileAdmin + '.output"' + #13#10 +
        ')' + #13#10,
        False);

      if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
         FileExists(TempOutputFile) and LoadStringFromFile(TempOutputFile, OutputContent) then
      begin
        Result := Trim(OutputContent);
        SaveStringToFile(LogFileAdmin, '【步骤4】从PowerShell解码后的文件读取密码成功' + #13#10, True);
      end
      else
      begin
        SaveStringToFile(LogFileAdmin, '【错误】PowerShell解码失败，无法获取管理员密码' + #13#10, True);
      end;
    end
    else
    begin
      SaveStringToFile(LogFileAdmin, '【错误】未找到包含密码的输入文件，获取密码失败' + #13#10, True);
    end;
  end
  else
  begin
    SaveStringToFile(LogFileAdmin, '【错误】执行批处理文件失败，返回代码: ' + IntToStr(ResultCode) + #13#10, True);
  end;

  // 记录结果
  if Result <> '' then
    SaveStringToFile(LogFileAdmin, '【完成】成功获取管理员密码' + #13#10, True)
  else
    SaveStringToFile(LogFileAdmin, '【失败】未能获取管理员密码' + #13#10, True);

  SaveStringToFile(LogFileAdmin, '==========================================' + #13#10, True);

  // 清理临时文件
  DeleteFile(TempInputFile);
  DeleteFile(TempOutputFile);
  DeleteFile(BatchFile);
end;

// 创建Devtron启动脚本
procedure CreateDevtronLauncherScript;
var
  ScriptPath, ScriptContent: string;
  LogFile: string;
  AnsiScriptFile: string;
  ResultCode: Integer;
begin
  ScriptPath := ExpandConstant('{app}\devtron_launcher.bat');
  LogFile := ExpandConstant('{app}\launcher_script.log');
  AnsiScriptFile := ExpandConstant('{app}\launcher_ansi.txt');

  // 记录创建启动脚本
  SaveStringToFile(LogFile, '==========================================' + #13#10, True);
  SaveStringToFile(LogFile, '【开始】创建Devtron启动脚本 - ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);

  // 记录URL和密码状态
  if DevtronUrl <> '' then
    SaveStringToFile(LogFile, '【信息】使用URL: ' + DevtronUrl + #13#10, True)
  else
    SaveStringToFile(LogFile, '【警告】URL未获取，将使用空值' + #13#10, True);

  if DevtronPassword <> '' then
    SaveStringToFile(LogFile, '【信息】管理员密码已获取' + #13#10, True)
  else
    SaveStringToFile(LogFile, '【警告】管理员密码未获取，将使用空值' + #13#10, True);

  // 创建批处理文件内容 - 使用简单的ANSI命令
  ScriptContent :=
    '@echo off' + #13#10 +
    'rem 首先设置代码页为简体中文GBK' + #13#10 +
    'chcp 936 > nul' + #13#10 + #13#10 +
    'echo ============================================================' + #13#10 +
    'echo                  Devtron控制台启动工具                      ' + #13#10 +
    'echo ============================================================' + #13#10 +
    'echo.' + #13#10 +
    'echo  正在启动Devtron控制台，请稍候...' + #13#10 +
    'echo.' + #13#10 + #13#10 +

    'rem 检查URL是否存在' + #13#10 +
    'if "' + Trim(DevtronUrl) + '" == "" (' + #13#10 +
    '    echo  [错误] Devtron URL未设置，无法启动控制台' + #13#10 +
    '    echo  请联系管理员获取正确的访问地址' + #13#10 +
    '    echo.' + #13#10 +
    '    goto end' + #13#10 +
    ')' + #13#10 + #13#10 +

    'rem 启动浏览器访问Devtron控制台' + #13#10 +
    'start "" "' + Trim(DevtronUrl) + ':22443"' + #13#10 + #13#10 +

    'timeout /t 2 > nul' + #13#10 +
    'cls' + #13#10 +
    'echo ============================================================' + #13#10 +
    'echo                 Devtron控制台已启动                         ' + #13#10 +
    'echo ============================================================' + #13#10 +
    'echo.' + #13#10 +
    'echo  Devtron控制台已在浏览器中打开' + #13#10 +
    'echo.' + #13#10 +
    'echo  [访问信息]' + #13#10 +
    'echo  访问地址: ' + Trim(DevtronUrl) + ':22443' + #13#10 +
    'echo  管理员账户: admin' + #13#10;

  // 根据是否获取到密码添加不同的内容
  if DevtronPassword <> '' then
    ScriptContent := ScriptContent +
    'echo  管理员密码: ' + DevtronPassword + #13#10
  else
    ScriptContent := ScriptContent +
    'echo  管理员密码: [未获取] 请通过以下命令获取:' + #13#10 +
    'echo  kubectl -n devtroncd get secret devtron-secret -o jsonpath=''{.data.ADMIN_PASSWORD}''' + #13#10 +
    'echo  并进行base64解码' + #13#10;

  // 添加结尾
  ScriptContent := ScriptContent +
    'echo.' + #13#10 +
    'echo  如需再次打开控制台，请重新运行此脚本' + #13#10 +
    'echo.' + #13#10 +
    'echo ============================================================' + #13#10 +
    ':end' + #13#10 +
    'echo.' + #13#10 +
    'echo 按任意键退出...' + #13#10 +
    'pause > nul';

  // 先保存为ANSI格式以支持中文(GBK)
  if SaveStringToFile(AnsiScriptFile, ScriptContent, False) then
  begin
    // 创建一个转换批处理文件
    SaveStringToFile(ExpandConstant('{app}\convert_bat.cmd'),
      '@echo off' + #13#10 +
      'chcp 936 > nul' + #13#10 +
      'type "' + AnsiScriptFile + '" > "' + ScriptPath + '"' + #13#10,
      False);

    // 执行转换
    //WizardForm.StatusLabel.Caption := '正在创建启动脚本...';
    if Exec(ExpandConstant('{cmd}'), '/c "' + ExpandConstant('{app}\convert_bat.cmd') + '"',
            '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      SaveStringToFile(LogFile, '【成功】启动脚本已创建: ' + ScriptPath + #13#10, True);
      DeleteFile(ExpandConstant('{app}\convert_bat.cmd'));
      DeleteFile(AnsiScriptFile);
    end
    else
    begin
      SaveStringToFile(LogFile, '【错误】无法转换启动脚本，错误码: ' + IntToStr(ResultCode) + #13#10, True);
      // 如果转换失败，直接保存原始文件
      SaveStringToFile(ScriptPath, ScriptContent, False);
    end;
  end
  else
  begin
    SaveStringToFile(LogFile, '【错误】无法创建临时脚本文件' + #13#10, True);
    // 直接保存脚本
    SaveStringToFile(ScriptPath, ScriptContent, False);
  end;

  SaveStringToFile(LogFile, '【完成】启动脚本创建处理完成' + #13#10, True);
  SaveStringToFile(LogFile, '==========================================' + #13#10, True);
end;

// 使用循环而不是定时器，确保进度条正常显示
procedure ProgressSimulationWithUIUpdate(const LogFile: string);
var
  i: Integer;
  TempBatchFile: string;
  ResultCode: Integer;
  OutputContent: AnsiString;
  KubeconfigPath: string;
  StartTime, CurrentDateTime: TDateTime;
  ElapsedSeconds, CurrentElapsed: Integer;
  StartupSeconds: Integer;
  CompleteFlagFile: string;
  ProgressValue: Integer;
begin
  KubeconfigPath := ExpandConstant('{app}\kubeconfig');
  StartTime := Now;
  CompleteFlagFile := ExpandConstant('{app}\progress_complete.flag');

  // 删除标记文件（如果存在）
  if FileExists(CompleteFlagFile) then
    DeleteFile(CompleteFlagFile);

  // 记录进度条开始
  SaveStringToFile(LogFile, '【进度】开始模拟服务启动进度...' + #13#10, True);

  // 设置总启动时间为110秒
  StartupSeconds := 110;

  // 使用非阻塞方式启动计时器进程
  TempBatchFile := ExpandConstant('{app}\progress_timer.bat');
  SaveStringToFile(TempBatchFile,
    '@echo off' + #13#10 +
    'for /L %%i in (1,1,' + IntToStr(StartupSeconds) + ') do (' + #13#10 +
    '  ping -n 2 127.0.0.1 > nul' + #13#10 +  // 使用ping作为延时约1秒
    ')' + #13#10 +
    'echo complete > "' + CompleteFlagFile + '"' + #13#10,
    False);

  // 启动计时器但不等待
  ShellExec('', ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewNoWait, ResultCode);

  // 初始化进度条
  WizardForm.ProgressGauge.Style := npbstNormal;
  WizardForm.ProgressGauge.Min := 0;
  WizardForm.ProgressGauge.Max := 100;
  WizardForm.ProgressGauge.Position := 0;

  i := 0;  // 当前进度

  // 循环直到计时器完成
  while not FileExists(CompleteFlagFile) do
  begin
    // 计算当前进度
    CurrentDateTime := Now;
    CurrentElapsed := Round((CurrentDateTime - StartTime) * 24 * 60 * 60);

    // 安全计算进度，避免超过100%
    ProgressValue := CurrentElapsed * 100 div StartupSeconds;
    if ProgressValue > 100 then
      ProgressValue := 100;
    i := ProgressValue;

    // 更新进度条
    WizardForm.ProgressGauge.Position := i;

    // 更新状态文本
    WizardForm.StatusLabel.Caption := '正在启动Devtron服务，请耐心等待...' + IntToStr(i) + '%';

    // 记录日志
    if (CurrentElapsed mod 10 = 0) and (CurrentElapsed > 0) then
      SaveStringToFile(LogFile, '【进度】服务启动进度: ' + IntToStr(i) + '%，已运行' + IntToStr(CurrentElapsed) + '秒' + #13#10, True);

    // 处理Windows消息以保持UI响应
    Application.ProcessMessages;

    // 短暂休眠
    Sleep(200);
  end;

  // 进度完成
  WizardForm.ProgressGauge.Position := 100;
  WizardForm.StatusLabel.Caption := '正在完成Devtron服务启动...100%';
  SaveStringToFile(LogFile, '【进度】服务启动进度: 100%' + #13#10, True);

  // 删除标记文件
  DeleteFile(CompleteFlagFile);

  // 完成服务启动，获取URL和密码
  SaveStringToFile(LogFile, '【获取信息】正在获取Devtron URL和密码...' + #13#10, True);

  TempBatchFile := ExpandConstant('{app}\get_devtron_url.bat');
  SaveStringToFile(TempBatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +
    'set KUBECONFIG=' + KubeconfigPath + #13#10 +
    'echo [命令] kubectl describe serviceexporter devtron-itf -n devtroncd > "' + ExpandConstant('{app}\url_command.log') + '" 2>&1' + #13#10 +
    '"' + ExpandConstant('{app}\kubectl.exe') + '" describe serviceexporter devtron-itf -n devtroncd > "' +
    ExpandConstant('{app}\devtron_url.txt') + '" 2>&1' + #13#10,
    False);

  // 执行获取URL的命令
  SaveStringToFile(LogFile, '【执行命令】获取Devtron URL...' + #13#10, True);
  if Exec(ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
     FileExists(ExpandConstant('{app}\devtron_url.txt')) and
     LoadStringFromFile(ExpandConstant('{app}\devtron_url.txt'), OutputContent) then
  begin
    DevtronUrl := ExtractDevtronUrl(OutputContent);
    if DevtronUrl <> '' then
      SaveStringToFile(LogFile, '【信息】成功获取Devtron URL: ' + DevtronUrl + #13#10, True)
    else
      SaveStringToFile(LogFile, '【警告】未能从输出中提取Devtron URL' + #13#10, True);
  end
  else
  begin
    SaveStringToFile(LogFile, '【错误】执行获取URL命令失败，错误代码: ' + IntToStr(ResultCode) + #13#10, True);
  end;

  if DevtronUrl = '' then
  begin
    SaveStringToFile(LogFile, '【警告】无法获取Devtron URL' + #13#10, True);
    //MsgBox('无法获取Devtron URL，请检查Devtron是否正常运行。', mbError, MB_OK);
  end;

  // 获取管理员密码
  SaveStringToFile(LogFile, '【执行命令】获取Devtron管理员密码...' + #13#10, True);
  DevtronPassword := GetDevtronAdminPassword();

  // 如果无法获取密码，显示提示
  if DevtronPassword = '' then
  begin
    SaveStringToFile(LogFile, '【警告】未能获取管理员密码' + #13#10, True);
    //MsgBox('Devtron安装已完成。安装完成后，您可以通过桌面快捷方式访问Devtron控制台。' + #13#10 +
    //       '无法自动获取Devtron管理员密码。您可以通过以下命令手动获取:' + #13#10 +
    //       'kubectl -n devtroncd get secret devtron-secret -o jsonpath=''{.data.ADMIN_PASSWORD}''  在进行 base64 解码',
    //       mbInformation, MB_OK);
  end
  else
  begin
    SaveStringToFile(LogFile, '【信息】成功获取管理员密码' + #13#10, True);
  end;

  // 创建启动脚本
  SaveStringToFile(LogFile, '【创建脚本】生成Devtron启动脚本...' + #13#10, True);
  CreateDevtronLauncherScript();

  // 计算总耗时
  ElapsedSeconds := Round((Now - StartTime) * 24 * 60 * 60);
  SaveStringToFile(LogFile, '【完成】服务启动流程已完成，总耗时: ' + IntToStr(ElapsedSeconds) + '秒' + #13#10, True);
  SaveStringToFile(LogFile, '===========================================================' + #13#10, True);

  // 完成提示
  MsgBox('Devtron安装和服务启动已完成，您可以通过桌面快捷方式访问Devtron控制台。', mbInformation, MB_OK);

  // 清理临时文件
  DeleteFile(TempBatchFile);
end;

// 更新服务启动进度
procedure UpdateServiceProgress(Sender: TObject);
var
  CurrentProgress: Integer;
  TempBatchFile: string;
  OutputContent: AnsiString;
  KubeconfigPath: string;
  ResultCode: Integer;
begin
  // 获取当前进度
  CurrentProgress := TTimer(Sender).Tag;

  // 更新进度条
  WizardForm.ProgressGauge.Position := CurrentProgress;

  // 更新状态文本
  WizardForm.StatusLabel.Caption := '正在启动Devtron服务，请耐心等待...' +
                                     IntToStr((CurrentProgress * 100) div 100) + '%';

  // 增加进度
  CurrentProgress := CurrentProgress + 1;
  TTimer(Sender).Tag := CurrentProgress;

  // 检查是否完成
  if CurrentProgress > 100 then
  begin
    // 停止定时器
    TTimer(Sender).Enabled := False;

    // 完成服务启动，获取URL和密码
    KubeconfigPath := ExpandConstant('{app}\kubeconfig');

    // 获取Devtron URL
    TempBatchFile := ExpandConstant('{app}\get_devtron_url.bat');
    SaveStringToFile(TempBatchFile,
      '@echo off' + #13#10 +
      'chcp 65001 > nul' + #13#10 +
      'set KUBECONFIG=' + KubeconfigPath + #13#10 +
      'echo [命令] kubectl describe serviceexporter devtron-itf -n devtroncd > "' + ExpandConstant('{app}\url_command.log') + '" 2>&1' + #13#10 +
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

    // 清理临时文件
    DeleteFile(TempBatchFile);
  end;
end;

// 处理安装完成后的操作
procedure ProcessInstallComplete;
var
  KubeconfigPath: string;
  LogFile: string;
begin
  // 记录日志文件路径
  LogFile := ExpandConstant('{app}\devtron_service.log');

  // 记录服务启动开始
  SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
  SaveStringToFile(LogFile, '【服务启动】开始启动Devtron服务 - ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);

  // 告知用户服务启动开始
  //MsgBox('Devtron安装完成，正在启动服务，请稍候...', mbInformation, MB_OK);

  KubeconfigPath := ExpandConstant('{app}\kubeconfig');

  // 使用WizardForm进度条
  WizardForm.StatusLabel.Caption := '正在启动Devtron服务，请耐心等待...';
  WizardForm.ProgressGauge.Style := npbstNormal;
  WizardForm.ProgressGauge.Min := 0;
  WizardForm.ProgressGauge.Max := 100;

  // 用简单方法代替计时器，确保UI更新
  // 这样我们直接使用阻塞方式但保持UI响应
  ProgressSimulationWithUIUpdate(LogFile);
end;

// 根据用户选择决定是否创建快捷方式
function ShouldCreateIcons: Boolean;
begin
  Result := DevtronPage.Values[0];
end;

// 代替定时器实现的非阻塞安装
function InstallDevtron: Boolean;
var
  LogFile, TempBatchFile, KubeconfigPath, CompleteFlagFile: string;
  ResultCode: Integer;
  StartDateTime, CurrentDateTime: TDateTime;
  ElapsedSeconds: Integer;
  MaxWaitTime: Integer;
begin
  Result := False;

  try
    // 初始化文件路径
    LogFile := ExpandConstant('{app}\devtron_install.log');
    KubeconfigPath := ExpandConstant('{app}\kubeconfig');
    CompleteFlagFile := ExpandConstant('{app}\install_complete.flag');

    // 确保标记文件不存在
    DeleteFile(CompleteFlagFile);

    // 记录安装开始 - 带时间戳
    SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
    SaveStringToFile(LogFile, '【开始安装】Devtron安装开始 - ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);
    SaveStringToFile(LogFile, '===========================================================' + #13#10, True);

    // 创建安装批处理文件
    TempBatchFile := ExpandConstant('{app}\devtron_install.bat');

    // 构建批处理文件内容 - 通过分段提高可读性
    SaveStringToFile(TempBatchFile,
      '@echo off' + #13#10 +
      'setlocal enabledelayedexpansion' + #13#10 +
      'chcp 65001 > nul' + #13#10 +
      'cd /d "' + ExpandConstant('{app}\devtron') + '"' + #13#10 +
      'set KUBECONFIG=' + KubeconfigPath + #13#10 + #13#10 +

      'echo [Step 1] Getting cluster information...' + #13#10 +
      'echo [Step 1] Getting cluster information... >> "' + LogFile + '.output" 2>&1' + #13#10 +
      '"' + ExpandConstant('{app}\kubectl.exe') + '" config view > config_view.txt 2>&1' + #13#10 + #13#10 +

      'set "server_url="' + #13#10 +
      'for /f "delims=" %%i in (''type config_view.txt ^| find "server:"'') do (' + #13#10 +
      '    set "line=%%i"' + #13#10 +
      '    for /f "tokens=1* delims= " %%a in ("!line!") do (' + #13#10 +
      '        if /i "%%a"=="server:" (' + #13#10 +
      '            set "server_url=%%b"' + #13#10 +
      '            goto :server_found' + #13#10 +
      '        )' + #13#10 +
      '    )' + #13#10 +
      ')' + #13#10 + #13#10 +

      ':server_found' + #13#10 +
      'if "!server_url!"=="" (' + #13#10 +
      '    echo [Error] Server field not found in kubeconfig! >> "' + LogFile + '.output" 2>&1' + #13#10 +
      '    exit /b 1' + #13#10 +
      ')' + #13#10 + #13#10 +

      'echo [Step 2] Starting Devtron installation...' + #13#10 +
      'echo [Step 2] Starting Devtron installation... >> "' + LogFile + '.output" 2>&1' + #13#10 + #13#10 +

      'echo [Step 2.1] Cleaning up existing installation (if any)... >> "' + LogFile + '.output" 2>&1' + #13#10 +
      '"' + ExpandConstant('{app}\kubectl.exe') + '" delete namespace devtroncd >> "' + LogFile + '.output" 2>&1' + #13#10 +
      '"' + ExpandConstant('{app}\helm.exe') + '" uninstall devtron --namespace devtroncd >> "' + LogFile + '.output" 2>&1' + #13#10 + #13#10 +

      'echo [Step 2.2] Parsing server parameters... >> "' + LogFile + '.output" 2>&1' + #13#10 +
      'for /f "tokens=2 delims=." %%a in ("!server_url!") do set "zoneID=%%a"' + #13#10 +
      'for /f "tokens=4 delims=/" %%a in ("!server_url!") do set "vksID=%%a"' + #13#10 + #13#10 +

      'echo [Info] zoneID: !zoneID! >> "' + LogFile + '.output" 2>&1' + #13#10 +
      'echo [Info] vksID: !vksID! >> "' + LogFile + '.output" 2>&1' + #13#10 + #13#10 +

      'echo [Step 2.3] Executing Helm installation... >> "' + LogFile + '.output" 2>&1' + #13#10 +
      '"' + ExpandConstant('{app}\helm.exe') + '" install devtron . --create-namespace -n devtroncd --values resources.yaml --set zoneID=!zoneID! --set vksID=!vksID! --set global.containerRegistry="registry.!zoneID!.alayanew.com:8443/vc-app_market/devtron" --timeout 300s >> "' + LogFile + '.output" 2>&1' + #13#10 + #13#10 +

      'echo [Step 2.4] Creating ConfigMap... >> "' + LogFile + '.output" 2>&1' + #13#10 +
      '"' + ExpandConstant('{app}\kubectl.exe') + '" create configmap devtron-global-config -n devtroncd --from-literal=vksID=!vksID! >> "' + LogFile + '.output" 2>&1' + #13#10 + #13#10 +

      'echo [Complete] Devtron installation completed >> "' + LogFile + '.output" 2>&1' + #13#10 +
      'echo Installation complete > "' + CompleteFlagFile + '"' + #13#10,
      False);

    // 在执行安装命令之前添加进度条准备
    WizardForm.ProgressGauge.Style := npbstMarquee; // 使用动态进度条样式
    WizardForm.StatusLabel.Caption := '正在安装Devtron，需要2-3分钟，请耐心等待...';

    SaveStringToFile(LogFile, '【安装开始】执行安装命令...' + #13#10, True);

    // 启动批处理但不等待完成
    if not ShellExec('', ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewNoWait, ResultCode) then
    begin
      Log('启动Devtron安装失败');
      SaveStringToFile(LogFile, '【错误】无法启动安装程序，错误代码: ' + IntToStr(ResultCode) + '，错误类型: mbError' + #13#10, True);
      //MsgBox('无法启动Devtron安装程序。错误代码: ' + IntToStr(ResultCode), mbError, MB_OK);
      WizardForm.ProgressGauge.Style := npbstNormal;
      WizardForm.ProgressGauge.Position := 0;
      Exit;
    end;

    // 记录开始时间
    StartDateTime := Now;
    // 最大等待时间，单位为秒（例如，等待10分钟）
    MaxWaitTime := 7 * 60;  // 10分钟

    // 循环等待安装完成，同时保持UI响应
    SaveStringToFile(LogFile, '【状态】等待安装过程完成...' + #13#10, True);

    while not FileExists(CompleteFlagFile) do
    begin
      // 处理消息让UI更流畅
      Application.ProcessMessages;

      // 计算已经过的时间（以秒为单位）
      CurrentDateTime := Now;
      ElapsedSeconds := Round((CurrentDateTime - StartDateTime) * 24 * 60 * 60);

      // 更新状态文本
      WizardForm.StatusLabel.Caption := '正在安装Devtron，需要2-3分钟，请耐心等待...（已运行' + IntToStr(ElapsedSeconds) + '秒）';

      // 每30秒记录一次等待状态
      if (ElapsedSeconds mod 30 = 0) and (ElapsedSeconds > 0) then
        SaveStringToFile(LogFile, '【状态】安装进行中...已等待' + IntToStr(ElapsedSeconds) + '秒' + #13#10, True);

      // 如果已经等待超过最大等待时间，则跳出循环
      if ElapsedSeconds >= MaxWaitTime then
      begin
        SaveStringToFile(LogFile, '【错误】安装超时，退出安装...' + #13#10, True);
        MsgBox('安装超时，程序将退出。', mbError, MB_OK);
        Exit;  // 退出安装
      end;

      // 短暂休眠，减少CPU使用
      Sleep(50);
    end;

    // 安装完成
    DeleteFile(CompleteFlagFile);
    WizardForm.ProgressGauge.Style := npbstNormal;
    WizardForm.ProgressGauge.Position := 100;
    WizardForm.StatusLabel.Caption := 'Devtron安装完成';

    // 记录安装完成
    SaveStringToFile(LogFile, '【安装完成】Devtron安装已完成，用时' + IntToStr(ElapsedSeconds) + '秒' + #13#10, True);
    SaveStringToFile(LogFile, '===========================================================' + #13#10, True);

    // 继续处理
    ProcessInstallComplete();

    Result := True;
  except
    //on E: Exception do
    begin
      // 详细记录错误信息
      Log('安装Devtron时发生错误: ' );
      SaveStringToFile(LogFile, '【错误】安装过程中出现异常: '  + #13#10, True);
      SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
      //MsgBox('安装Devtron时发生错误: '  + #13#10 + '请检查日志了解详情。', mbError, MB_OK);
    end;
  end;
end;

//------------------------------------------------------------------------------
// 安装事件处理
//------------------------------------------------------------------------------

// 安装后处理
procedure CurStepChanged(CurStep: TSetupStep);
var
  KubeconfigPath, DecodedFile, ToolsPath: string;
  DecodingSuccess: Boolean;
  LogFile: string;
begin
  if CurStep = ssPostInstall then
  begin
    // 初始化日志文件
    LogFile := ExpandConstant('{app}\setup_post_install.log');
    SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
    SaveStringToFile(LogFile, '【开始】安装后处理流程 - ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);
    SaveStringToFile(LogFile, '===========================================================' + #13#10, True);

    // 设置环境变量
    ToolsPath := ExpandConstant('{app}');
    SaveStringToFile(LogFile, '【步骤1】添加应用程序目录到系统PATH: ' + ToolsPath + #13#10, True);
    AddToSystemPathEnvironmentVariable(ToolsPath);
    SaveStringToFile(LogFile, '【步骤1】PATH环境变量已更新' + #13#10, True);

    // 处理kubeconfig文件
    SaveStringToFile(LogFile, '【步骤2】开始处理kubeconfig文件' + #13#10, True);
    KubeconfigPath := KubeconfigPage.Values[0];
    SaveStringToFile(LogFile, '【步骤2.1】源kubeconfig路径: ' + KubeconfigPath + #13#10, True);
    DecodedFile := ExpandConstant('{app}\kubeconfig');
    SaveStringToFile(LogFile, '【步骤2.2】目标kubeconfig路径: ' + DecodedFile + #13#10, True);

    // 解码或复制kubeconfig文件
    SaveStringToFile(LogFile, '【步骤3】处理kubeconfig文件' + #13#10, True);
    DecodingSuccess := Base64DecodeFile(KubeconfigPath, DecodedFile);

    if DecodingSuccess then
    begin
      SaveStringToFile(LogFile, '【步骤3】kubeconfig文件处理成功' + #13#10, True);

      // 设置环境变量
      SaveStringToFile(LogFile, '【步骤4】设置KUBECONFIG环境变量: ' + DecodedFile + #13#10, True);
      SetSystemEnvironmentVariable('KUBECONFIG', DecodedFile);
      SaveStringToFile(LogFile, '【步骤4】KUBECONFIG环境变量已设置' + #13#10, True);

      // 确保配置生效
      SaveStringToFile(LogFile, '【步骤5】测试KUBECONFIG配置是否生效' + #13#10, True);
      if not EnsureKubeconfigWorks(DecodedFile) then
      begin
        SaveStringToFile(LogFile, '【警告】KUBECONFIG测试未通过，可能需要重启计算机' + #13#10, True);
        MsgBox('KUBECONFIG环境变量已设置，但可能需要重启计算机才能完全生效。安装将继续进行。', mbInformation, MB_OK);
      end
      else
      begin
        SaveStringToFile(LogFile, '【步骤5】KUBECONFIG测试通过' + #13#10, True);
      end;

      // 根据用户选择决定是否安装Devtron
      if DevtronPage.Values[0] then
      begin
        SaveStringToFile(LogFile, '【信息】用户选择安装Devtron' + #13#10, True);
        if InstallDevtron() then
          SaveStringToFile(LogFile, '【成功】Devtron安装流程完成' + #13#10, True)
        else
          SaveStringToFile(LogFile, '【错误】Devtron安装流程执行失败' + #13#10, True);
      end
      else
      begin
        SaveStringToFile(LogFile, '【信息】用户选择不安装Devtron' + #13#10, True);
        MsgBox('已跳过Devtron安装。您仍然可以通过命令行工具（kubectl和helm）管理Kubernetes集群。', mbInformation, MB_OK);
      end;
    end
    else
    begin
      SaveStringToFile(LogFile, '【错误】kubeconfig文件处理失败' + #13#10, True);
      SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
      MsgBox('无法处理Kubeconfig文件。请确认文件格式正确或联系管理员获取帮助。', mbError, MB_OK);
      Exit;
    end;

    SaveStringToFile(LogFile, '【完成】安装后处理流程结束 - ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);
    SaveStringToFile(LogFile, '===========================================================' + #13#10, True);
  end;
end;
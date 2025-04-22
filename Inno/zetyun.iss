#include <D:\Program Files (x86)\Inno Download Plugin\idp.iss>
; 基本信息设置
#define MyAppName "AlayaNeWTools"
#define MyAppVersion "1.0"
#define MyAppPublisher "北京九章云极科技有限公司"
#define MyAppURL "https://www.datacanvas.com"
#define MyAppExeName "AlayaNeWTools.exe"

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


[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
; 将kubectl.exe复制到安装目录
Source: "D:\exe\kubectl.exe"; DestDir: "{app}"; Flags: ignoreversion
; 将helm.exe复制到安装目录
Source: "D:\exe\helm.exe"; DestDir: "{app}"; Flags: ignoreversion
; 复制Devtron安装文件
Source: "D:\exe\devtron\*"; DestDir: "{app}\devtron"; Flags: ignoreversion recursesubdirs createallsubdirs
;确保图标文件被正确复制
Source: "D:\exe\favicon.ico"; DestDir: "{app}"; DestName: "app_icon.ico"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\Devtron控制台"; Filename: "{app}\devtron_launcher.bat"; IconFilename: "{app}\app_icon.ico"; IconIndex: 0; Comment: "启动Devtron控制台"; WorkingDir: "{app}"

[Code]
var
  KubeconfigPage: TInputFileWizardPage;
  DevtronPage: TInputOptionWizardPage;
  DevtronUrl: string;
  DevtronPassword: string;

// 创建自定义页面
procedure InitializeWizard;
begin
  // 创建Kubeconfig文件选择页面
  KubeconfigPage := CreateInputFilePage(wpSelectDir,
    '选择Kubeconfig文件',
    '请选择您的Kubeconfig文件，该文件将被配置为环境变量。此步骤是必需的。',
    '选择文件:');
  KubeconfigPage.Add('Kubeconfig文件 (必需):', 'JSON files|*.json|YAML files|*.yaml|YML files|*.yml|All files|*.*', '.json');

  //创建Devtron安装选项页面
  // DevtronPage := CreateInputOptionPage(KubeconfigPage.ID,
    // '安装Devtron',
    // '是否安装Devtron平台？',
    // '选择是否安装Devtron平台。安装后将创建桌面快捷方式以访问Devtron控制台。',
    // False, False);
  // DevtronPage.Add('安装Devtron平台');
  // DevtronPage.Values[0] := True; // 默认选中
end;

// 验证用户是否选择了文件
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if CurPageID = KubeconfigPage.ID then
  begin
    // 检查是否选择了文件
    if (KubeconfigPage.Values[0] = '') or (not FileExists(KubeconfigPage.Values[0])) then
    begin
      MsgBox('请选择有效的Kubeconfig文件。此步骤是必需的，无法继续安装。', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

// 使用 certutil 进行 Base64 解码
function Base64DecodeFile(const InputFile, OutputFile: string): Boolean;
var
  ResultCode: Integer;
  ExecResult: Boolean;
  CmdLine: string;
  TempOutputFile: string;
begin
  // 尝试在临时目录中创建输出文件，以避免权限问题
  TempOutputFile := ExpandConstant('{tmp}\kubeconfig_temp');

  // 构建命令行
  CmdLine := 'certutil -decode "' + InputFile + '" "' + TempOutputFile + '"';

  // 记录将要执行的命令
  Log('执行命令: ' + CmdLine);

  // 执行命令
  ExecResult := Exec('certutil.exe', '-decode "' + InputFile + '" "' + TempOutputFile + '"',
                '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // 记录执行结果
  Log('命令执行结果: ' + IntToStr(Integer(ExecResult)) + ', 返回代码: ' + IntToStr(ResultCode));

  // 检查执行结果
  if not ExecResult then
  begin
    MsgBox('无法执行 certutil 命令。错误代码: ' + IntToStr(ResultCode) +
           '。这可能是由于权限不足或磁盘空间不足。', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  // 检查返回代码
  if ResultCode <> 0 then
  begin
    MsgBox('kubeconfig 返回错误代码: ' + IntToStr(ResultCode) +
           '。这可能是由于 kubeconfig 文件格式问题或权限不足。', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  // 检查临时输出文件是否创建
  if not FileExists(TempOutputFile) then
  begin
    MsgBox('解码后的临时文件未创建。解码失败。', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  // 尝试将临时文件复制到最终位置
  if not FileCopy(TempOutputFile, OutputFile, False) then
  begin
    MsgBox('无法将解码后的文件复制到最终位置。这可能是由于权限不足。', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  // 删除临时文件
  DeleteFile(TempOutputFile);

  // 显示成功消息
  //MsgBox('文件成功解码。', mbInformation, MB_OK);
  Result := True;
end;

// 添加到系统PATH环境变量，保留现有值
procedure AddToSystemPathEnvironmentVariable(const Value: string);
var
  CurrentPath: string;
  NewPath: string;
begin
  // 尝试获取系统PATH环境变量
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', CurrentPath) then
  begin
    // 检查值是否已存在于PATH中
    if Pos(LowerCase(Value), LowerCase(CurrentPath)) = 0 then
    begin
      // 确保PATH以分号结尾
      if (Length(CurrentPath) > 0) and (CurrentPath[Length(CurrentPath)] <> ';') then
        CurrentPath := CurrentPath + ';';

      // 添加新路径
      NewPath := CurrentPath + Value;

      // 写入注册表
      if not RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', NewPath) then
        MsgBox('无法更新系统PATH环境变量。请确保以管理员身份运行安装程序。', mbError, MB_OK);
    end;
  end
  else
  begin
    // 如果系统PATH不存在（极少情况），尝试创建它
    if not RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', Value) then
      MsgBox('无法创建系统PATH环境变量。请确保以管理员身份运行安装程序。', mbError, MB_OK);
  end;
end;

// 设置系统环境变量KUBECONFIG
procedure SetSystemEnvironmentVariable(const Name, Value: string);
begin
  if not RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', Name, Value) then
    MsgBox('无法设置系统环境变量 ' + Name + '。请确保以管理员身份运行安装程序。', mbError, MB_OK);
end;

// 执行命令并获取输出 - 修复版
function ExecAndGetOutput(const Command, Params: string): string;
var
  OutputFile: string;
  ResultCode: Integer;
  Output: AnsiString;
  CmdLine: string;
  BatchFile: string;
begin
  Result := '';
  // 使用安装目录而非临时目录
  OutputFile := ExpandConstant('{app}\cmd_output.txt');
  BatchFile := ExpandConstant('{app}\run_cmd.bat');

  // 构建完整命令行
  CmdLine := '"' + Command + '" ' + Params;

  // 记录将要执行的命令
  Log('执行命令: ' + CmdLine + ' > ' + OutputFile);

  // 创建批处理文件来执行命令
  SaveStringToFile(BatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +  // 设置UTF-8编码
    CmdLine + ' > "' + OutputFile + '" 2>&1' + #13#10,
    False);

  // 执行批处理文件
  if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    // 检查命令执行结果
    Log('命令执行完成，返回代码: ' + IntToStr(ResultCode));

    // 等待一会儿确保文件写入完成
    Sleep(2000);

    // 检查输出文件是否存在
    if FileExists(OutputFile) then
    begin
      if LoadStringFromFile(OutputFile, Output) then
      begin
        Result := Output;
        Log('获取到输出，长度: ' + IntToStr(Length(Result)) + '，内容: ' + Result);
      end
      else
      begin
        Log('无法读取输出文件');
        MsgBox('无法读取命令输出文件: ' + OutputFile, mbError, MB_OK);
      end
    end
    else
    begin
      Log('输出文件不存在: ' + OutputFile);
      MsgBox('命令输出文件不存在: ' + OutputFile, mbError, MB_OK);
    end;
  end
  else
  begin
    Log('执行命令失败，错误代码: ' + IntToStr(ResultCode));
    MsgBox('执行命令失败，错误代码: ' + IntToStr(ResultCode), mbError, MB_OK);
  end;

  // 清理批处理文件
  DeleteFile(BatchFile);
end;

// 从输出中提取Devtron URL - 改进版
function ExtractDevtronUrl(const Output: string): string;
var
  UrlPos, UrlEnd: Integer;
  SearchStr, FullOutput: string;
begin
  Result := '';
  FullOutput := Output;

  // 记录完整输出以便调试
  Log('提取URL的完整输出: ' + FullOutput);

  // 尝试多种可能的搜索字符串
  SearchStr := 'IngressRoute successfully updated, url: https://';
  UrlPos := Pos(SearchStr, FullOutput);

  if UrlPos = 0 then
  begin
    // 尝试其他可能的格式
    SearchStr := 'url: https://';
    UrlPos := Pos(SearchStr, FullOutput);
  end;

  if UrlPos = 0 then
  begin
    // 尝试查找任何https://
    SearchStr := 'https://';
    UrlPos := Pos(SearchStr, FullOutput);
  end;

  if UrlPos > 0 then
  begin
    // 调整位置到https://开始处
    UrlPos := UrlPos + Length(SearchStr) - Length('https://');

    // 查找URL结束位置（空格、换行符或字符串结束）
    UrlEnd := Pos(' ', Copy(FullOutput, UrlPos, Length(FullOutput)));
    if UrlEnd = 0 then
      UrlEnd := Pos(#13, Copy(FullOutput, UrlPos, Length(FullOutput)));
    if UrlEnd = 0 then
      UrlEnd := Pos(#10, Copy(FullOutput, UrlPos, Length(FullOutput)));

    if UrlEnd = 0 then
      UrlEnd := Length(FullOutput) - UrlPos + 1
    else
      UrlEnd := UrlEnd - 1;

    // 提取URL
    Result := Copy(FullOutput, UrlPos, UrlEnd);

    // 添加端口号（如果URL中没有端口号）
    if Pos(':', Result) = 0 then
      Result := Result + ':22443';

    Log('提取到的URL: ' + Result);
  end
  else
    Log('未能在输出中找到URL');
end;

// Base64解码 - 使用certutil
function DecodeBase64(const Input: string): string;
var
  TempInputFile, TempOutputFile: string;
  ResultCode: Integer;
  Output: AnsiString;
begin
  Result := '';

  // 创建临时文件
  TempInputFile := ExpandConstant('{tmp}\base64_input.txt');
  TempOutputFile := ExpandConstant('{tmp}\base64_output.txt');

  // 保存输入到临时文件
  SaveStringToFile(TempInputFile, Input, False);

  // 使用certutil解码
  if Exec('certutil', '-decode "' + TempInputFile + '" "' + TempOutputFile + '"',
          '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    // 读取解码结果
    if LoadStringFromFile(TempOutputFile, Output) then
      Result := Output;
  end;

  // 清理临时文件
  DeleteFile(TempInputFile);
  DeleteFile(TempOutputFile);
end;

// 使用 certutil 进行 Base64 解码的函数
function DecodeBase64WithCertUtil(const Input: string): string;
var
  TempInputFile, TempOutputFile: string;
  ResultCode: Integer;
  Output: AnsiString;
  BatchFile: string;
begin
  Result := '';

  // 创建临时文件
  TempInputFile := ExpandConstant('{tmp}\certutil_input.txt');
  TempOutputFile := ExpandConstant('{tmp}\certutil_output.txt');
  BatchFile := ExpandConstant('{tmp}\certutil_decode.bat');

  // 保存输入到临时文件
  if not SaveStringToFile(TempInputFile, Input, False) then
  begin
    Log('无法创建临时输入文件: ' + TempInputFile);
    Exit;
  end;

  // 构建批处理文件
  if not SaveStringToFile(BatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +
    'certutil -decode "' + TempInputFile + '" "' + TempOutputFile + '" > "' + ExpandConstant('{tmp}\certutil_log.txt') + '" 2>&1' + #13#10,
    False) then
  begin
    Log('无法创建临时批处理文件: ' + BatchFile);
    Exit;
  end;

  // 执行批处理文件
  Log('执行批处理文件: ' + BatchFile);
  if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    // 检查命令执行结果
    Log('certutil 命令执行完成，返回代码: ' + IntToStr(ResultCode));

    // 读取日志文件以便调试
    if FileExists(ExpandConstant('{tmp}\certutil_log.txt')) then
    begin
      if LoadStringFromFile(ExpandConstant('{tmp}\certutil_log.txt'), Output) then
        Log('certutil 执行日志: ' + Output);
    end;

    // 读取解码结果
    if FileExists(TempOutputFile) then
    begin
      if LoadStringFromFile(TempOutputFile, Output) then
      begin
        Result := Output;
        Log('Base64 解码成功，结果长度: ' + IntToStr(Length(Result)));
      end
      else
      begin
        Log('无法读取 certutil 解码输出文件');
      end;
    end
    else
    begin
      Log('certutil 解码输出文件不存在: ' + TempOutputFile);
    end;
  end
  else
  begin
    Log('无法执行 certutil 解码命令，错误代码: ' + IntToStr(ResultCode));
  end;

  // 清理临时文件
  DeleteFile(TempInputFile);
  DeleteFile(TempOutputFile);
  DeleteFile(BatchFile);
  DeleteFile(ExpandConstant('{tmp}\certutil_log.txt'));
end;

// 替换原来的 DecodeBase64WithPowerShell 函数
function DecodeBase64WithPowerShell(const Input: string): string;
begin
  // 直接调用 certutil 版本
  Result := DecodeBase64WithCertUtil(Input);
end;

// 创建Devtron启动脚本
procedure CreateDevtronLauncherScript;
var
  ScriptPath: string;
  ScriptContent: string;
begin
  ScriptPath := ExpandConstant('{app}\devtron_launcher.bat');

  // 创建脚本内容
  ScriptContent := '@echo off' + #13#10 +
                  'echo 正在启动Devtron控制台...' + #13#10 +
                  'start "" "' + Trim(DevtronUrl) + ':22443"' + #13#10 + // Trim 处理
                  'echo.' + #13#10 +
                  'echo Devtron控制台已启动' + #13#10 +
                  'echo 访问地址: ' + Trim(DevtronUrl) + ':22443' + #13#10 +
                  'echo 管理员账户: admin'  + #13#10 +
                  'echo 管理员密码: ' + DevtronPassword + #13#10 +
                  'echo.' + #13#10 +
                  'pause';

  // 保存脚本
  SaveStringToFile(ScriptPath, ScriptContent, False);
end;

// 专门用于获取 Devtron 管理员密码的函数
// 专门用于获取 Devtron 管理员密码的函数
function GetDevtronAdminPassword: string;
var
  TempInputFile, TempOutputFile, BatchFile: string;
  CmdLine, Output: string;
  ResultCode: Integer;
  OutputContent: AnsiString;
begin
  Result := '';

  // 创建临时文件
  TempInputFile := ExpandConstant('{tmp}\admin_pwd_input.txt');
  TempOutputFile := ExpandConstant('{tmp}\admin_pwd_output.txt');
  BatchFile := ExpandConstant('{tmp}\decode_pwd.bat');

  // 使用批处理文件获取密码并解码
  SaveStringToFile(BatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +
    'set KUBECONFIG=' + ExpandConstant('{app}\kubeconfig') + #13#10 +
    'echo 正在获取Devtron管理员密码...' + #13#10 +
    '"' + ExpandConstant('{app}\kubectl.exe') + '" -n devtroncd get secret devtron-secret -o jsonpath="{.data.ADMIN_PASSWORD}" > "' + TempInputFile + '" 2>&1' + #13#10 +
    'if exist "' + TempInputFile + '" (' + #13#10 +
    '  for /f "delims=" %%a in (''type "' + TempInputFile + '"'') do (' + #13#10 +
    '    echo %%a > "' + TempInputFile + '.clean"' + #13#10 +
    '  )' + #13#10 +
    '  move /y "' + TempInputFile + '.clean" "' + TempInputFile + '" > nul' + #13#10 +
    '  certutil -decode "' + TempInputFile + '" "' + TempOutputFile + '" > nul' + #13#10 +
    ')' + #13#10,
    False);

  // 执行批处理文件
  if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    // 检查输出文件是否存在
    if FileExists(TempOutputFile) then
    begin
      if LoadStringFromFile(TempOutputFile, OutputContent) then
      begin
        // 移除可能的空白字符和换行符
        Result := Trim(OutputContent);
        Log('成功获取 Devtron 管理员密码，长度: ' + IntToStr(Length(Result)));
      end;
    end
    else
    begin
      Log('密码输出文件不存在: ' + TempOutputFile);
    end;

    // 如果密码为空，尝试直接读取输入文件并手动解码
    if Result = '' then
    begin
      if FileExists(TempInputFile) and LoadStringFromFile(TempInputFile, OutputContent) then
      begin
        Output := Trim(OutputContent);
        Log('获取到的Base64密码: ' + Output);

        // 尝试使用PowerShell解码
        SaveStringToFile(BatchFile,
          '@echo off' + #13#10 +
          'chcp 65001 > nul' + #13#10 +
          'powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(''' + Output + '''))" > "' + TempOutputFile + '"' + #13#10,
          False);

        if Exec(ExpandConstant('{cmd}'), '/c "' + BatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        begin
          if FileExists(TempOutputFile) and LoadStringFromFile(TempOutputFile, OutputContent) then
          begin
            Result := Trim(OutputContent);
            Log('使用PowerShell解码成功，密码长度: ' + IntToStr(Length(Result)));
          end;
        end;
      end;
    end;
  end
  else
  begin
    Log('执行获取密码命令失败，错误代码: ' + IntToStr(ResultCode));
  end;

  // 清理临时文件
  DeleteFile(TempInputFile);
  DeleteFile(TempInputFile + '.clean');
  DeleteFile(TempOutputFile);
  DeleteFile(BatchFile);
end;

// 修改 InstallDevtron 函数，确保 helm 命令能够读取 kubeconfig 配置
function InstallDevtron: Boolean;
var
  ResultCode: Integer;
  CmdLine: string;
  Output: string;
  LogFile: string;
  TempBatchFile: string;
  KubeconfigPath: string;
  OutputContent: AnsiString;
begin
  Result := False;

  try
    // 将日志文件保存到安装目录
    LogFile := ExpandConstant('{app}\devtron_install.log');

    // 记录安装开始
    SaveStringToFile(LogFile, '开始安装Devtron: ' + GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + #13#10, True);

    // 获取 kubeconfig 路径
    KubeconfigPath := ExpandConstant('{app}\kubeconfig');

    // 创建批处理文件，显式设置 KUBECONFIG 环境变量
    TempBatchFile := ExpandConstant('{app}\devtron_install.bat');
    // SaveStringToFile(TempBatchFile,
      // '@echo off' + #13#10 +
      // 'chcp 65001 > nul' + #13#10 +
      // 'echo 开始安装 Devtron...' + #13#10 +
      // 'cd /d "' + ExpandConstant('{app}\devtron') + '"' + #13#10 +
      // 'set KUBECONFIG=' + KubeconfigPath + #13#10 +

      // 'echo 正在尝试获取集群ID...' + #13#10 +
      // 'for /f "tokens=*" %%a in (''"' + ExpandConstant('{app}\kubectl.exe') + '" --kubeconfig=' + KubeconfigPath + ' cluster-info'') do echo %%a >> cluster_info.txt' + #13#10 +
      // 'type cluster_info.txt | findstr "vksid" > vksid_info.txt' + #13#10 +
      // 'for /f "tokens=*" %%a in (vksid_info.txt) do set vksid=%%a' + #13#10 +
      // 'if defined vksid (' + #13#10 +
      // '  echo 找到原始vksid信息: %vksid%' + #13#10 +
      // '  set vksid=%vksid:*vksid=%' + #13#10 +
      // '  echo 提取后的vksid: %vksid%' + #13#10 +
      // '  set vksid=%vksid:~1%' + #13#10 +
      // '  echo 最终的集群ID: %vksid%' + #13#10 +
      // ') else (' + #13#10 +
      // '  echo 未找到vksid信息，将使用默认值' + #13#10 +
      // '  set vksid=default-cluster' + #13#10 +
      // ')' + #13#10 +
      // '"' + ExpandConstant('{app}\helm.exe') + '" install devtron . --create-namespace -n devtroncd --values resources.yaml --timeout 300s > "' + LogFile + '.output" 2>&1' + #13#10 +


      // 'echo 安装完成，返回代码: %ERRORLEVEL%' + #13#10,
      // False);

    SaveStringToFile(TempBatchFile,
      '@echo off' + #13#10 +
      'chcp 65001 > nul' + #13#10 +
      'echo 开始安装 Devtron...' + #13#10 +
      'cd /d "' + ExpandConstant('{app}\devtron') + '"' + #13#10 +
      'set KUBECONFIG=' + KubeconfigPath + #13#10 +
      'echo 正在尝试获取集群ID...' + #13#10 +
      'echo 执行命令: "' + ExpandConstant('{app}\kubectl.exe') + '" cluster-info > cluster_info.txt' + #13#10 +
      '"' + ExpandConstant('{app}\kubectl.exe') + '" cluster-info > cluster_info.txt 2>&1' + #13#10 +
      'echo 检查cluster_info.txt文件是否生成:' + #13#10 +
      'if exist cluster_info.txt (' + #13#10 +
      '  echo cluster_info.txt 已成功生成' + #13#10 +
      '  type cluster_info.txt' + #13#10 +
      ') else (' + #13#10 +
      '  echo 错误: cluster_info.txt 未能生成' + #13#10 +
      ')' + #13#10 +
      'echo 正在提取集群ID...' + #13#10 +
      'for /f "delims=" %%a in (''type cluster_info.txt ^| find "inCluster"'') do (' + #13#10 +
      '  echo 找到行: %%a' + #13#10 +
      '  for /f "tokens=8 delims=/ " %%b in ("%%a") do set vksid=%%b' + #13#10 +
      ')' + #13#10 +
      'echo 提取的集群ID: %vksid%' + #13#10 +
      'echo 开始安装Devtron，使用集群ID: %vksid%' + #13#10 +
      'if defined vksid (' + #13#10 +
      '  echo 执行命令: "' + ExpandConstant('{app}\helm.exe') + '" install devtron . --create-namespace -n devtroncd --values resources.yaml --set --set global.vksID=%vksid% --timeout 300s' + #13#10 +
      '  "' + ExpandConstant('{app}\helm.exe') + '" install devtron . --create-namespace -n devtroncd --values resources.yaml --set global.vksID=%vksid% --timeout 300s > "' + LogFile + '.output" 2>&1' + #13#10 +
      ') else (' + #13#10 +
      '  echo 执行命令: "' + ExpandConstant('{app}\helm.exe') + '" install devtron . --create-namespace -n devtroncd --values resources.yaml --timeout 300s' + #13#10 +
      '  "' + ExpandConstant('{app}\helm.exe') + '" install devtron . --create-namespace -n devtroncd --values resources.yaml --timeout 300s > "' + LogFile + '.output" 2>&1' + #13#10 +
      ')' + #13#10 +
      'echo 创建 devtron-global-config configmap...' + #13#10 +
      'echo 执行命令: "' + ExpandConstant('{app}\kubectl.exe') + '" create configmap devtron-global-config -n devtroncd --from-literal=vksID=%vksid%' + #13#10 +
      '"' + ExpandConstant('{app}\kubectl.exe') + '" create configmap devtron-global-config -n devtroncd --from-literal=vksID=%vksid% >> "' + LogFile + '.output" 2>&1' + #13#10 +
      'echo 安装完成，返回代码: %ERRORLEVEL%' + #13#10 ,
      False);
    // 执行批处理文件
    if not Exec(ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      Log('启动Devtron安装失败，错误代码: ' + IntToStr(ResultCode));
      MsgBox('启动Devtron安装失败。错误代码: ' + IntToStr(ResultCode), mbError, MB_OK);
      Exit;
    end;

    MsgBox('Devtron正在启动中，请等待约1分钟...', mbInformation, MB_OK);
    Sleep(80000); // 等待20秒，注释中说90秒但实际是20000毫秒

    // 获取Devtron URL - 修改为使用批处理文件并明确设置KUBECONFIG
    TempBatchFile := ExpandConstant('{tmp}\get_devtron_url.bat');
    SaveStringToFile(TempBatchFile,
      '@echo off' + #13#10 +
      'chcp 65001 > nul' + #13#10 +
      'set KUBECONFIG=' + KubeconfigPath + #13#10 +
      '"' + ExpandConstant('{app}\kubectl.exe') + '" describe serviceexporter devtron-itf -n devtroncd > "' +
      ExpandConstant('{app}\devtron_url.txt') + '" 2>&1' + #13#10,
      False);

    // 执行批处理文件
    if Exec(ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      // 读取输出文件
      if FileExists(ExpandConstant('{app}\devtron_url.txt')) and
         LoadStringFromFile(ExpandConstant('{app}\devtron_url.txt'), OutputContent) then
      begin
        Output := OutputContent;
      end;
    end;

    // 清理临时文件
    DeleteFile(TempBatchFile);

    DevtronUrl := ExtractDevtronUrl(Output);
    if DevtronUrl <> '' then
      //MsgBox('Devtron URL: ' + DevtronUrl, mbInformation, MB_OK)
    else
      MsgBox('无法获取 Devtron URL，请检查 Devtron 是否正常运行。', mbError, MB_OK);

    // 获取管理员密码 - 使用新的专用函数
    DevtronPassword := GetDevtronAdminPassword();

  // 如果无法获取密码，显示提示信息
    if DevtronPassword = '' then
    begin
      MsgBox('无法自动获取 Devtron 管理员密码。' + #13#10 +
            '您可以稍后使用以下命令获取:' + #13#10 +
            'kubectl -n devtroncd get secret devtron-secret -o jsonpath=''{.data.ADMIN_PASSWORD}''  在进行 base64 解码',
            mbInformation, MB_OK);
    end;


    // 创建启动脚本，即使URL未知也创建
    CreateDevtronLauncherScript();

    MsgBox('Devtron安装已完成。' + #13#10 +
           '安装完成后，您可以通过桌面快捷方式访问Devtron控制台。' + #13#10 ,
            mbInformation, MB_OK);

    Result := True;
  except

  end;

  // 清理临时文件
  DeleteFile(TempBatchFile);
end;

// 添加这个函数到您的代码中，用于确保 kubeconfig 立即生效
function EnsureKubeconfigWorks(const KubeconfigPath: string): Boolean;
var
  ResultCode: Integer;
  TempBatchFile: string;
  Output: string;
begin
  Result := False;

  // 创建临时批处理文件，设置环境变量并测试 kubectl
  TempBatchFile := ExpandConstant('{tmp}\ensure_kubeconfig.bat');
  SaveStringToFile(TempBatchFile,
    '@echo off' + #13#10 +
    'chcp 65001 > nul' + #13#10 +
    'echo 正在设置 KUBECONFIG 环境变量...' + #13#10 +
    'set KUBECONFIG=' + KubeconfigPath + #13#10 +
    'setx KUBECONFIG "' + KubeconfigPath + '" /M > nul' + #13#10 +
    'echo 正在验证 kubectl 配置...' + #13#10 +
    '"' + ExpandConstant('{app}\kubectl.exe') + '" config view > "' + ExpandConstant('{tmp}\kubectl_config_test.txt') + '" 2>&1' + #13#10,
    False);

  // 执行批处理文件
  if Exec(ExpandConstant('{cmd}'), '/c "' + TempBatchFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Log('kubeconfig 环境变量设置完成，返回代码: ' + IntToStr(ResultCode));
    Result := True;
  end;

  // 清理临时文件
  DeleteFile(TempBatchFile);
  DeleteFile(ExpandConstant('{tmp}\kubectl_config_test.txt'));
end;

// 修改 CurStepChanged 函数中处理 kubeconfig 的部分
procedure CurStepChanged(CurStep: TSetupStep);
var
  KubeconfigPath: string;
  DecodedFile: string;
  DecodingSuccess: Boolean;
  ToolsPath: string;
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // 获取工具所在的完整路径
    ToolsPath := ExpandConstant('{app}');

    // 添加工具目录到系统PATH环境变量
    AddToSystemPathEnvironmentVariable(ToolsPath);

    // 处理kubeconfig文件
    KubeconfigPath := KubeconfigPage.Values[0];

    // 直接进行Base64解码，不再询问
    DecodedFile := ExpandConstant('{app}\kubeconfig');

    // 使用certutil进行解码
    DecodingSuccess := Base64DecodeFile(KubeconfigPath, DecodedFile);

    if DecodingSuccess then
    begin
      // 使用标准方法设置环境变量
      SetSystemEnvironmentVariable('KUBECONFIG', DecodedFile);

      // 确保 kubeconfig 立即生效
      if EnsureKubeconfigWorks(DecodedFile) then
      begin
        Log('kubeconfig 配置已成功设置并生效1hh');
      end
      else
      begin
        MsgBox('KUBECONFIG 环境变量已设置，但可能需要重启计算机才能完全生效。', mbInformation, MB_OK);
      end;
    end
    else
    begin
      // 解码失败，使用原始文件
      MsgBox('KUBECONFIG 解码失败，终止安装', mbError, MB_OK);
      Abort;  // 终止安装
    end;

    // 安装Devtron
    InstallDevtron();

    // 验证工具安装
    //MsgBox('安装完成。您现在可以使用以下命令验证安装:' + #13#10 +
     //     '- kubectl version' + #13#10 +
      //     '- helm version', mbInformation, MB_OK);

    // 通知系统环境变量已更改
    //MsgBox('系统环境变量已更新。您可能需要重新启动计算机以使更改生效。', mbInformation, MB_OK);
  end;
end;
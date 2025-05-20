@echo off
setlocal enabledelayedexpansion

:: 逐行查找server URL
set "server_url="
for /f "delims=" %%i in ('kubectl config view 2^>^&1') do (
    set "line=%%i"
    :: 去除行首空格
    for /f "tokens=1* delims= " %%a in ("!line!") do (
        if /i "%%a"=="server:" (
            set "server_url=%%b"
            goto :server_found
        )
    )
)

:server_found
if "!server_url!"=="" (
    echo Error: Missing 'server' field in kubeconfig
    exit /b 1
)

:: 提取zone-id（从vcluster.后到第一个.前）
for /f "tokens=2 delims=." %%a in ("!server_url!") do set "zoneID=%%a"

:: 提取cluster-id（inCluster/后的部分）
for /f "tokens=4 delims=/" %%a in ("!server_url!") do set "vksID=%%a"

:: 验证结果
if "!zoneID!"=="" (
    echo Error: Failed to extract zone-id from URL
    echo Expected format: https://vcluster.^<zone-id^>.alayanew.com:21443/inCluster/^<vks-id^>
    echo Actual URL: !server_url!
    exit /b 1
)

if "!vksID!"=="" (
    echo Error: Failed to extract cluster-id from URL
    echo Expected format: https://vcluster.^<zone-id^>.alayanew.com:21443/inCluster/^<vks-id^>
    echo Actual URL: !server_url!
    exit /b 1
)

:: 输出结果
echo zoneID: !zoneID!
echo vksID: !vksID!

helm install devtron . --create-namespace -n devtroncd --values resources.yaml --set zoneID=!zoneID! --set vksID=!vksID! --set global.containerRegistry="registry.!zoneID!.alayanew.com:8443/vc-app_market/devtron"

endlocal
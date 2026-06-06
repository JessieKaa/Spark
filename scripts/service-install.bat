@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================
::  Spark Client - Windows 服务安装脚本
::  需要以管理员权限运行
:: ============================================

set "SERVICE_NAME=SparkClient"
set "SERVICE_DISPLAY=Spark Client Service"
set "SERVICE_DESC=Spark remote administration client"

:: 获取当前目录
set "SCRIPT_DIR=%~dp0"
set "BINARY_PATH=%SCRIPT_DIR%SparkClient.exe"

:: 检查是否以管理员权限运行
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请以管理员权限运行此脚本
    pause
    exit /b 1
)

:: 检查可执行文件是否存在
if not exist "%BINARY_PATH%" (
    echo [错误] 未找到 %BINARY_PATH%
    echo        请将此脚本放在 SparkClient.exe 同目录下运行
    pause
    exit /b 1
)

:: 检查服务是否已存在
sc query "%SERVICE_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo [警告] 服务 "%SERVICE_NAME%" 已存在，正在删除旧服务...
    net stop "%SERVICE_NAME%" >nul 2>&1
    sc delete "%SERVICE_NAME%" >nul 2>&1
    timeout /t 2 /nobreak >nul
)

:: 安装服务（binPath 使用绝对路径）
echo [安装] 正在创建服务...
sc create "%SERVICE_NAME%" binPath= "%BINARY_PATH%" start= auto DisplayName= "%SERVICE_DISPLAY%"
if %errorlevel% neq 0 (
    echo [错误] 服务创建失败
    pause
    exit /b 1
)

:: 设置服务描述
sc description "%SERVICE_NAME%" "%SERVICE_DESC%"

:: 配置服务失败后自动重启（第一次失败后延迟 30 秒重启）
sc failure "%SERVICE_NAME%" reset= 86400 actions= restart/30000/restart/30000/restart/60000

:: 启动服务
echo [启动] 正在启动服务...
net start "%SERVICE_NAME%"
if %errorlevel% neq 0 (
    echo [警告] 服务启动失败，请检查可执行文件是否正常
)

echo.
echo [完成] 服务 "%SERVICE_NAME%" 已安装并设为开机自启
echo        可执行文件: %BINARY_PATH%
echo        启动类型:   自动
echo.
pause

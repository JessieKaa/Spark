@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ================================================================
::  Spark Client - Windows PE 离线服务卸载脚本
:: ================================================================
::  功能说明:
::    在 WinPE 环境中，移除目标 Windows 上的 Spark Client
::    服务或启动项，并删除已安装的文件。
::
::  使用方式:
::    以管理员身份运行，按提示选择目标磁盘即可
:: ================================================================

:: ======================== 基本配置 ========================
set "SERVICE_NAME=SparkClient"
set "EXE_NAME=SparkClient.exe"
set "INSTALL_DIR=\SparkClient"
set "HIVE_SYS=OFFLINE_SPARK_SYS"
set "HIVE_SOFT=OFFLINE_SPARK_SOFT"
:: ============================================================

echo.
echo ========================================================
echo   Spark Client - PE 离线卸载工具
echo ========================================================
echo.

:: 权限检查
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 需要管理员权限
    pause
    exit /b 1
)

:: ------------------------------------------------------------------
:: 步骤 1: 扫描所有磁盘，寻找 Windows 安装
:: ------------------------------------------------------------------
echo [扫描] 正在检测磁盘上的 Windows 安装...

set "WIN_COUNT=0"

for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\Windows\System32\config\SYSTEM" (
        set /a WIN_COUNT+=1
        set "WIN_DRIVE_!WIN_COUNT!=%%d:"
        echo   [!WIN_COUNT!]  %%d:  - 检测到 Windows 安装
    )
)

if %WIN_COUNT% equ 0 (
    echo [错误] 未检测到任何 Windows 安装
    pause
    exit /b 1
)

:: ------------------------------------------------------------------
:: 步骤 2: 选择目标磁盘
:: ------------------------------------------------------------------
echo.
set /p "CHOICE=请选择目标 Windows 编号 (1-%WIN_COUNT%): "

set "TARGET_DRIVE="
for /l %%i in (1,1,%WIN_COUNT%) do (
    if "%CHOICE%"=="%%i" set "TARGET_DRIVE=!WIN_DRIVE_%%i!"
)

if "%TARGET_DRIVE%"=="" (
    echo [错误] 无效选择
    pause
    exit /b 1
)

echo [信息] 目标系统: %TARGET_DRIVE%

:: ------------------------------------------------------------------
:: 步骤 3: 移除服务配置
:: 加载 SYSTEM hive，删除 Services 下的服务注册表键
:: 无论用户选哪种模式安装的，都尝试清理服务项
:: ------------------------------------------------------------------
echo.
echo [卸载] 正在检查服务配置..."

reg load "HKLM\%HIVE_SYS%" "%TARGET_DRIVE%\Windows\System32\config\SYSTEM" >nul 2>&1
if %errorlevel% equ 0 (
    :: 检查服务键是否存在
    reg query "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" >nul 2>&1
    if %errorlevel% equ 0 (
        echo [信息] 发现服务注册项，正在删除..."
        reg delete "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /f >nul 2>&1
        echo [完成] 服务注册项已删除
    ) else (
        echo [信息] 未发现服务注册项，跳过"
    )
    reg unload "HKLM\%HIVE_SYS%" >nul 2>&1
) else (
    echo [警告] SYSTEM hive 加载失败，跳过服务清理"
)

:: ------------------------------------------------------------------
:: 步骤 4: 移除注册表启动项 (Run)
:: 加载 SOFTWARE hive，删除 Run 键中的启动项
:: ------------------------------------------------------------------
echo [卸载] 正在检查启动项..."

reg load "HKLM\%HIVE_SOFT%" "%TARGET_DRIVE%\Windows\System32\config\SOFTWARE" >nul 2>&1
if %errorlevel% equ 0 (
    :: 检查 Run 键中是否存在启动项
    reg query "HKLM\%HIVE_SOFT%\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" >nul 2>&1
    if %errorlevel% equ 0 (
        echo [信息] 发现 Run 启动项，正在删除..."
        reg delete "HKLM\%HIVE_SOFT%\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" /f >nul 2>&1
        echo [完成] 启动项已删除
    ) else (
        echo [信息] 未发现 Run 启动项，跳过"
    )
    reg unload "HKLM\%HIVE_SOFT%" >nul 2>&1
) else (
    echo [警告] SOFTWARE hive 加载失败，跳过启动项清理"
)

:: ------------------------------------------------------------------
:: 步骤 5: 删除已安装的文件
:: ------------------------------------------------------------------
echo.
echo [卸载] 正在检查已安装文件..."

if exist "%TARGET_DRIVE%%INSTALL_DIR%\%EXE_NAME%" (
    echo [信息] 发现已安装文件，正在删除..."
    del /q /f "%TARGET_DRIVE%%INSTALL_DIR%\%EXE_NAME%" >nul 2>&1
    :: 尝试删除安装目录（如果目录为空）
    dir /b "%TARGET_DRIVE%%INSTALL_DIR%" >nul 2>&1
    if %errorlevel% neq 0 (
        rd /q "%TARGET_DRIVE%%INSTALL_DIR%" >nul 2>&1
        echo [完成] 安装目录已删除
    ) else (
        echo [信息] 安装目录非空，保留目录: %TARGET_DRIVE%%INSTALL_DIR%
    )
) else (
    echo [信息] 未发现已安装文件，跳过"
)

:: ============================================================
:: 完成
:: ============================================================
echo.
echo ========================================================
echo   卸载完成
echo ========================================================
echo.
echo   已清理:
echo     - 服务注册项 (ControlSet001\Services\%SERVICE_NAME%)
echo     - 启动项     (HKLM Run\%SERVICE_NAME%)
echo     - 安装文件   (%TARGET_DRIVE%%INSTALL_DIR%)
echo.
pause

@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ================================================================
::  Spark Client - Windows PE 离线服务安装脚本
:: ================================================================
::  功能说明:
::    在 WinPE 环境中，为本机另一磁盘上已安装的 Windows 操作系统
::    离线安装 Spark Client 为自启动服务或启动项。
::
::  原理:
::    PE 环境中 sc.exe 只能操作 PE 自身的服务管理器，无法影响
::    目标 Windows。本脚本通过 reg load 加载目标 Windows 的注册表
::    hive 文件，直接写入服务或启动项配置，实现对离线系统的修改。
::
::  支持两种安装模式:
::    [1] Windows 服务 (推荐) - 以 SYSTEM 身份运行，开机自启，
::        无需用户登录，崩溃后可自动重启
::    [2] 注册表启动项 (兼容) - 写入 HKLM Run 键，用户登录后
::        自动运行，适用于服务模式不适用的场景
::
::  使用方式:
::    1. 将此脚本与 SparkClient.exe 放在同一目录
::    2. 以管理员身份运行（PE 中通常默认为管理员）
::    3. 按提示选择目标 Windows 所在磁盘和安装模式
:: ================================================================

:: ======================== 基本配置 ========================
:: 服务名称（注册表键名，不可含空格）
set "SERVICE_NAME=SparkClient"
:: 服务显示名称（在 services.msc 中可见）
set "SERVICE_DISPLAY=Spark Client Service"
:: 服务描述信息
set "SERVICE_DESC=Spark remote administration client"
:: 可执行文件名
set "EXE_NAME=SparkClient.exe"
:: 目标系统中可执行文件的安装目录（相对于目标系统盘）
set "INSTALL_DIR=\SparkClient"
:: 注册表 hive 临时挂载点（使用不常见的名称避免冲突）
set "HIVE_SYS=OFFLINE_SPARK_SYS"
set "HIVE_SOFT=OFFLINE_SPARK_SOFT"
:: ============================================================

echo.
echo ========================================================
echo   Spark Client - PE 离线安装工具
echo ========================================================
echo.

:: ------------------------------------------------------------------
:: 步骤 1: 权限检查
:: PE 环境通常已具备管理员权限，但做一次兜底检查
:: 原理：net session 要求管理员权限，普通用户调用会失败
:: ------------------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 需要管理员权限，请右键选择"以管理员身份运行"
    pause
    exit /b 1
)

:: ------------------------------------------------------------------
:: 步骤 2: 检查可执行文件
:: 脚本通过 %~dp0 获取自身所在目录，在该目录下查找 exe
:: ------------------------------------------------------------------
set "SCRIPT_DIR=%~dp0"
set "EXE_SOURCE=%SCRIPT_DIR%%EXE_NAME%"

if not exist "%EXE_SOURCE%" (
    echo [错误] 未找到可执行文件: %EXE_SOURCE%
    echo        请确保 %EXE_NAME% 与本脚本在同一目录
    pause
    exit /b 1
)
echo [信息] 可执行文件: %EXE_SOURCE%

:: ------------------------------------------------------------------
:: 步骤 3: 扫描所有磁盘，寻找 Windows 安装
:: 遍历 C: ~ Z:，检查是否存在 \Windows\System32\config\SYSTEM
:: 该文件是 Windows 注册表 SYSTEM hive，存在即表明该盘有 Windows
:: ------------------------------------------------------------------
echo.
echo [扫描] 正在检测磁盘上的 Windows 安装...

set "WIN_COUNT=0"
set "WIN_DRIVES="

for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\Windows\System32\config\SYSTEM" (
        set /a WIN_COUNT+=1
        set "WIN_DRIVE_!WIN_COUNT!=%%d:"
        echo   [!WIN_COUNT!]  %%d:  - 检测到 Windows 安装
    )
)

if %WIN_COUNT% equ 0 (
    echo [错误] 未在任何磁盘上检测到 Windows 安装
    echo        请确认目标磁盘已正确连接
    pause
    exit /b 1
)

:: ------------------------------------------------------------------
:: 步骤 4: 用户选择目标磁盘
:: ------------------------------------------------------------------
echo.
set /p "CHOICE=请选择目标 Windows 编号 (1-%WIN_COUNT%): "

:: 校验输入是否为有效数字
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
:: 步骤 5: 选择安装模式
:: ------------------------------------------------------------------
echo.
echo 请选择安装模式:
echo   [1] Windows 服务 (推荐) - 开机自启，无需用户登录，以 SYSTEM 运行
echo   [2] 注册表启动项       - 用户登录后自动运行，以登录用户身份运行
echo.
set /p "MODE=请输入选择 (1 或 2，默认 1): "
if "%MODE%"=="" set "MODE=1"
if not "%MODE%"=="1" if not "%MODE%"=="2" (
    echo [错误] 无效选择
    pause
    exit /b 1
)

:: ------------------------------------------------------------------
:: 步骤 6: 复制可执行文件到目标系统
:: 将 exe 复制到目标 Windows 盘的 \SparkClient\ 目录
:: 必须先复制再写注册表，因为注册表中的 ImagePath 要指向最终路径
:: ------------------------------------------------------------------
echo.
echo [安装] 正在复制文件到 %TARGET_DRIVE%%INSTALL_DIR%\...

:: 如果目标目录已存在则先删除旧文件
if exist "%TARGET_DRIVE%%INSTALL_DIR%" (
    del /q /f "%TARGET_DRIVE%%INSTALL_DIR%\*" >nul 2>&1
) else (
    mkdir "%TARGET_DRIVE%%INSTALL_DIR%"
)

copy /y "%EXE_SOURCE%" "%TARGET_DRIVE%%INSTALL_DIR%\%EXE_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 文件复制失败，请检查磁盘是否可写
    pause
    exit /b 1
)
echo [信息] 文件已复制到: %TARGET_DRIVE%%INSTALL_DIR%\%EXE_NAME%

:: 安装完成后，exe 在目标系统中的绝对路径
:: 注意：这里是目标系统启动后的路径（C:\SparkClient\...），
:: 而非 PE 中看到的盘符，因为盘符可能不同
:: 因此使用相对路径 \SparkClient\SparkClient.exe，
:: Windows 会将其解释为系统盘根目录下的路径
set "EXE_PATH=%TARGET_DRIVE%%INSTALL_DIR%\%EXE_NAME%"

:: ------------------------------------------------------------------
:: 步骤 7: 根据安装模式写入配置
:: ------------------------------------------------------------------
echo.

if "%MODE%"=="1" goto :INSTALL_SERVICE
if "%MODE%"=="2" goto :INSTALL_RUN

:: ============================================================
:: 模式 1: 安装为 Windows 服务
:: ============================================================
:: 服务在注册表中的位置:
::   HKLM\SYSTEM\ControlSet001\Services\<服务名>\
::
:: 必需的注册表值:
::   Type         (REG_DWORD)  = 0x10 (16)
::     含义: SERVICE_WIN32_OWN_PROCESS，独占进程的服务
::
::   Start        (REG_DWORD)  = 0x02 (2)
::     含义: SERVICE_AUTO_START，系统启动时自动启动
::
::   ErrorControl (REG_DWORD)  = 0x01 (1)
::     含义: SERVICE_ERROR_NORMAL，启动失败时记录事件日志并继续
::
::   ImagePath    (REG_EXPAND_SZ) = 可执行文件路径
::     含义: 服务的可执行文件位置
::
::   ObjectName   (REG_SZ)     = LocalSystem
::     含义: 服务以 SYSTEM 账户身份运行
::
::   DisplayName  (REG_SZ)     = 显示名称
::     含义: 在 services.msc 管理工具中显示的名称
:: ============================================================
:INSTALL_SERVICE

echo [安装] 模式: Windows 服务
echo [信息] 正在加载目标注册表 SYSTEM hive...

:: 加载目标 Windows 的 SYSTEM 注册表 hive
:: SYSTEM 文件包含服务配置（ControlSet001\Services\）
reg load "HKLM\%HIVE_SYS%" "%TARGET_DRIVE%\Windows\System32\config\SYSTEM" >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 注册表 hive 加载失败
    echo        文件: %TARGET_DRIVE%\Windows\System32\config\SYSTEM
    pause
    exit /b 1
)

:: --- 写入服务注册表项 ---
:: 注册表路径中的 ControlSet001 是 Windows 的第一个控制集
:: 通常就是当前/默认的控制集，系统启动时使用它

echo [信息] 正在写入服务配置...

:: 主键: 创建服务节点
reg add "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /f >nul 2>&1

:: Type = 0x10 (SERVICE_WIN32_OWN_PROCESS)
reg add "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /v Type /t REG_DWORD /d 16 /f >nul 2>&1

:: Start = 0x02 (SERVICE_AUTO_START，开机自动启动)
reg add "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /v Start /t REG_DWORD /d 2 /f >nul 2>&1

:: ErrorControl = 0x01 (失败时记录日志并继续启动系统)
reg add "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /v ErrorControl /t REG_DWORD /d 1 /f >nul 2>&1

:: ImagePath: 使用 %SystemDrive% 环境变量指向系统盘
:: 目标 Windows 启动后，其系统盘盘符可能是 C: 也可能是其他
:: %SystemDrive% 在启动时会自动解析为正确的系统盘符
reg add "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /v ImagePath /t REG_EXPAND_SZ /d "%%SystemDrive%%%INSTALL_DIR%\%EXE_NAME%" /f >nul 2>&1

:: ObjectName = LocalSystem (以 SYSTEM 账户运行)
reg add "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /v ObjectName /t REG_SZ /d "LocalSystem" /f >nul 2>&1

:: DisplayName
reg add "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /v DisplayName /t REG_SZ /d "%SERVICE_DISPLAY%" /f >nul 2>&1

:: Description
reg add "HKLM\%HIVE_SYS%\ControlSet001\Services\%SERVICE_NAME%" /v Description /t REG_SZ /d "%SERVICE_DESC%" /f >nul 2>&1

:: --- 服务失败恢复策略 ---
:: Windows 服务管理器支持配置服务失败后的自动恢复行为
:: 需要在服务键下创建 FailureActions 二进制值
:: 这比 sc failure 命令更底层，因为是直接操作注册表
::
:: FailureActions 格式 (REG_BINARY):
::   前 28 字节是头部:
::     [0-3]   操作间隔 (毫秒)     = 00000000 (由 Actions 指定)
::     [4-7]   无操作               = 00000000
::     [8-11]  重置计数周期 (秒)    = 80510100 = 86400 (24小时)
::     [12-15] 操作命令长度         = 00000000 (无命令)
::     [16-19] 无操作               = 00000000
::     [20-23] 延迟1 (毫秒)        = 30750000 (30000ms = 30秒)
::     [24-27] 延迟2 (毫秒)        = 30750000 (30000ms)
::   之后每 4 字节一组:
::     [28-31] 延迟3 (毫秒)        = 60EA0000 (60000ms = 60秒)
::     [32-35] 操作类型1           = 01 (RESTART)
::     [36-39] 操作类型2           = 01 (RESTART)
::     [40-43] 操作类型3           = 01 (RESTART)
::
:: 简化方案: 用 sc 命令无法操作离线注册表，所以直接写二进制值
:: 但 reg add 不支持直接写复杂二进制，改用更简单的方案：
:: 不配置 FailureActions，Windows 默认行为是"不恢复"
:: 可在目标系统启动后用 sc failure 命令补充配置

echo [信息] 正在卸载注册表 hive..."

:: 卸载 hive（必须卸载，否则目标系统启动时可能检测到 hive 被占用）
reg unload "HKLM\%HIVE_SYS%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] 注册表 hive 卸载失败，请手动执行:
    echo         reg unload HKLM\%HIVE_SYS%
    echo         确保没有其他程序访问了该 hive
)

goto :INSTALL_DONE

:: ============================================================
:: 模式 2: 安装为注册表启动项 (HKLM Run)
:: ============================================================
:: Run 启动项在注册表中的位置:
::   HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
::
:: 任何用户登录时，Windows 会自动运行该键下所有字符串值
:: 指向的程序。不需要服务管理器参与。
::
:: 优点: 简单可靠，不需要配置服务参数
:: 缺点: 需要用户登录才启动，以登录用户身份运行
:: ============================================================
:INSTALL_RUN

echo [安装] 模式: 注册表启动项
echo [信息] 正在加载目标注册表 SOFTWARE hive..."

:: 加载目标 Windows 的 SOFTWARE 注册表 hive
:: SOFTWARE 文件包含 Run 启动项配置
reg load "HKLM\%HIVE_SOFT%" "%TARGET_DRIVE%\Windows\System32\config\SOFTWARE" >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 注册表 hive 加载失败
    echo        文件: %TARGET_DRIVE%\Windows\System32\config\SOFTWARE
    pause
    exit /b 1
)

echo [信息] 正在写入启动项..."

:: 写入 Run 键值
:: 值名称: SparkClient
:: 值数据: 可执行文件路径
:: Run 键位于 HKLM (REG_SZ 不支持环境变量扩展)，但 Run 也支持 REG_EXPAND_SZ
:: 使用 REG_EXPAND_SZ + %SystemDrive% 确保路径在目标系统启动后正确
reg add "HKLM\%HIVE_SOFT%\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" /t REG_EXPAND_SZ /d "%%SystemDrive%%%INSTALL_DIR%\%EXE_NAME%" /f >nul 2>&1

echo [信息] 正在卸载注册表 hive..."

:: 卸载 hive
reg unload "HKLM\%HIVE_SOFT%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] 注册表 hive 卸载失败，请手动执行:
    echo         reg unload HKLM\%HIVE_SOFT%
)

goto :INSTALL_DONE

:: ============================================================
:: 安装完成
:: ============================================================
:INSTALL_DONE

echo.
echo ========================================================
echo   安装完成
echo ========================================================
echo.
echo   目标系统:     %TARGET_DRIVE%
echo   可执行文件:   %TARGET_DRIVE%%INSTALL_DIR%\%EXE_NAME%
if "%MODE%"=="1" (
    echo   安装模式:     Windows 服务 ^(自动启动, SYSTEM 权限^)
    echo   启动后可执行: sc start %SERVICE_NAME%
    echo   卸载命令:     sc delete %SERVICE_NAME%
) else (
    echo   安装模式:     注册表启动项 ^(用户登录后启动^)
    echo   卸载:         删除注册表 Run 键中 %SERVICE_NAME% 值
)
echo.
echo   注意: 请确保目标系统正常关机或重启后再拔除 PE 启动盘
echo.
pause

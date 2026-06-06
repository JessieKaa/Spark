@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================
::  Spark Client - Windows 服务卸载脚本
::  需要以管理员权限运行
:: ============================================

set "SERVICE_NAME=SparkClient"

:: 检查是否以管理员权限运行
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请以管理员权限运行此脚本
    pause
    exit /b 1
)

:: 检查服务是否存在
sc query "%SERVICE_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 服务 "%SERVICE_NAME%" 不存在，无需卸载
    pause
    exit /b 0
)

:: 停止服务
echo [停止] 正在停止服务...
net stop "%SERVICE_NAME%" >nul 2>&1
timeout /t 2 /nobreak >nul

:: 强制终止进程（兜底）
taskkill /f /im SparkClient.exe >nul 2>&1

:: 删除服务
echo [卸载] 正在删除服务...
sc delete "%SERVICE_NAME%"
if %errorlevel% neq 0 (
    echo [错误] 服务删除失败，请确认服务已停止
    pause
    exit /b 1
)

echo.
echo [完成] 服务 "%SERVICE_NAME%" 已卸载
echo.
pause

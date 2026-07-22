@echo off
REM CMD/双击入口,委托给 pack-windows.ps1
setlocal
set "HERE=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%pack-windows.ps1" %*
set RC=%ERRORLEVEL%
REM 双击场景下出错时保留窗口,让用户看清错误(CI 定义 CI=true 时跳过)
if %RC% NEQ 0 if not defined CI pause
exit /b %RC%

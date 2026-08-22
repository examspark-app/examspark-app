@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-web.ps1"
if errorlevel 1 (
  echo.
  echo Deployment failed.
  exit /b 1
)
pause
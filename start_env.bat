@echo off
echo ===========================================
echo   Starting Local Development Environment
echo ===========================================
echo.

echo [1/2] Starting Vagrant Virtual Machine...
vagrant up
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to start Vagrant VM.
    pause
    exit /b %ERRORLEVEL%
)
echo [OK] Vagrant VM is running.
echo.

echo [2/2] Starting GitHub Actions Runner...
if exist "actions-runner\run.cmd" (
    echo Starting runner in a new window...
    start "GitHub Actions Runner" cmd.exe /c "cd actions-runner && run.cmd"
    echo [OK] Runner started.
) else (
    echo [ERROR] actions-runner\run.cmd not found!
)
echo.

echo ===========================================
echo   Environment started successfully!
echo ===========================================
pause

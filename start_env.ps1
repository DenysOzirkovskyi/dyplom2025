<#
.SYNOPSIS
    Скрипт для запуску локального середовища (Vagrant VM + GitHub Actions Runner)
#>

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Starting Local Development Environment   " -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Запуск Vagrant VM
Write-Host "[1/2] Starting Vagrant Virtual Machine..." -ForegroundColor Yellow
vagrant up
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start Vagrant VM. Exit code: $LASTEXITCODE" -ForegroundColor Red
    Pause
    exit $LASTEXITCODE
}
Write-Host "[OK] Vagrant VM is running." -ForegroundColor Green
Write-Host ""

# 2. Зняття блокувань Windows (Device Guard / Mark of the Web) з файлів ранера
Write-Host "[*] Unblocking GitHub Runner files..." -ForegroundColor Yellow
if (Test-Path "actions-runner\bin") {
    Get-ChildItem -Path "actions-runner\bin" -Recurse -File | Where-Object { $_.Extension -match "\.(exe|dll)$" } | Unblock-File -ErrorAction SilentlyContinue
    Write-Host "[OK] Files unblocked." -ForegroundColor Green
}

# 3. Запуск GitHub Actions Runner
Write-Host "[2/2] Starting GitHub Actions Runner..." -ForegroundColor Yellow
if (Test-Path "actions-runner\run.cmd") {
    Write-Host "Starting runner in a new window..." -ForegroundColor Yellow
    # Запускаємо runner в окремому вікні, щоб він не блокував консоль
    Start-Process cmd.exe -ArgumentList "/k `"cd actions-runner && run.cmd`"" -PassThru
    Write-Host "[OK] Runner started." -ForegroundColor Green
} else {
    Write-Host "[ERROR] actions-runner\run.cmd not found! Make sure the runner is configured." -ForegroundColor Red
}
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Environment started successfully!        " -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

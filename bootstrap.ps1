# Bootstrap entrypoint for Windows
# This script ensures git is available, clones/updates the repo, and runs the installer
#
# Usage:
#   irm https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.ps1 | iex

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/CaduVarela/zed-config.git"
$RepoDir = "$env:USERPROFILE\.config\zed-bootstrap"

Write-Host "Zed Bootstrap (Windows)" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host ""

# Check if git is available
$gitPath = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitPath) {
    Write-Host "Git is not installed. Please install Git and try again." -ForegroundColor Red
    Write-Host "You can download Git from https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

Write-Host "Ensuring repository is cloned/updated..."
if (Test-Path $RepoDir) {
    Write-Host "Updating existing repository..." -ForegroundColor Cyan
    git -C $RepoDir pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to update repository" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Cloning repository..." -ForegroundColor Cyan
    git clone $RepoUrl $RepoDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to clone repository" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Running installer..." -ForegroundColor Cyan
& "$RepoDir\src\windows\install.ps1" -RepoRoot $RepoDir

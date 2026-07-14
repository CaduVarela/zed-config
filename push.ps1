# Push entrypoint for Windows
# Updates the local repo, then copies live Zed config back into it and pushes.
#
# Usage:
#   irm https://raw.githubusercontent.com/CaduVarela/zed-config/master/push.ps1 | iex

$ErrorActionPreference = "Stop"

$RepoDir = "$env:USERPROFILE\.config\zed-bootstrap"

Write-Host "Zed Config Push (Windows)" -ForegroundColor Green
Write-Host "==========================" -ForegroundColor Green
Write-Host ""

if (-not (Test-Path $RepoDir)) {
    Write-Host "No local repo found at $RepoDir - run bootstrap.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "Updating local repo before push..." -ForegroundColor Cyan
git -C $RepoDir pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to update repository (resolve manually before pushing)" -ForegroundColor Red
    exit 1
}

Write-Host ""
& "$RepoDir\src\windows\push.ps1" -RepoRoot $RepoDir

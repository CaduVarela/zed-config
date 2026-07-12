# Main installation orchestrator for Windows

param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Zed bootstrap on Windows..." -ForegroundColor Green
Write-Host "Repository root: $RepoRoot" -ForegroundColor Cyan

# Source paths
. "$PSScriptRoot\paths.ps1"

Write-Host "`nStep 1: Installing prerequisites..." -ForegroundColor Yellow
& "$PSScriptRoot\prerequisites.ps1" -RepoRoot $RepoRoot

# Create Zed config directory if it doesn't exist
if (-not (Test-Path $ZedConfigDir)) {
    Write-Host "Creating Zed config directory: $ZedConfigDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $ZedConfigDir -Force | Out-Null
}

# Create extensions directory if it doesn't exist
if (-not (Test-Path $ZedExtensionsDir)) {
    Write-Host "Creating Zed extensions directory: $ZedExtensionsDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $ZedExtensionsDir -Force | Out-Null
}

# Function to backup existing files
function Backup-IfExists {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$FilePath.bak-$timestamp"
        Write-Host "Backing up existing file to: $backupPath" -ForegroundColor Cyan
        Copy-Item $FilePath -Destination $backupPath
    }
}

# Copy configuration files
Write-Host "`nStep 2: Copying configuration files..." -ForegroundColor Yellow

Backup-IfExists $ZedSettingsFile
Copy-Item "$RepoRoot\config\settings.json" -Destination $ZedSettingsFile -Force
Write-Host "Copied settings.json" -ForegroundColor Green

Backup-IfExists $ZedKeymapFile
Copy-Item "$RepoRoot\config\keymap.json" -Destination $ZedKeymapFile -Force
Write-Host "Copied keymap.json" -ForegroundColor Green

Backup-IfExists $ZedAgentsFile
Copy-Item "$RepoRoot\config\AGENTS.md" -Destination $ZedAgentsFile -Force
Write-Host "Copied AGENTS.md" -ForegroundColor Green

# Sync theme extension
Write-Host "`nStep 3: Syncing theme extension..." -ForegroundColor Yellow

$manifestPath = "$RepoRoot\theme\manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    $themeRepo = $manifest.repo
    $extensionId = $manifest.extension_id

    $themeCacheDir = "$env:TEMP\zed-theme-sync"
    $themeInstallDir = "$ZedExtensionsDir\$extensionId"

    # Clone or update theme repository
    if (Test-Path $themeCacheDir) {
        Write-Host "Updating theme repository..." -ForegroundColor Cyan
        git -C $themeCacheDir pull --ff-only origin master 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to update theme, re-cloning..." -ForegroundColor Yellow
            Remove-Item $themeCacheDir -Recurse -Force
            git clone $themeRepo $themeCacheDir
        }
    } else {
        Write-Host "Cloning theme repository..." -ForegroundColor Cyan
        git clone $themeRepo $themeCacheDir
    }

    # Mirror theme to extensions directory
    Write-Host "Mirroring theme to extensions directory..." -ForegroundColor Cyan
    if (Test-Path $themeInstallDir) {
        Remove-Item $themeInstallDir -Recurse -Force
    }
    robocopy $themeCacheDir $themeInstallDir /MIR /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

    Write-Host "Theme synced successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: manifest.json not found" -ForegroundColor Yellow
}

Write-Host "`n✓ Zed bootstrap completed successfully!" -ForegroundColor Green
Write-Host "Please restart Zed to apply all changes." -ForegroundColor Cyan

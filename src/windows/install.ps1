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
& "$PSScriptRoot\prerequisites.ps1"

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

$configFiles = @(
    @{ Name = "settings.json"; Dest = $ZedSettingsFile },
    @{ Name = "keymap.json"; Dest = $ZedKeymapFile },
    @{ Name = "AGENTS.md"; Dest = $ZedAgentsFile }
)

foreach ($file in $configFiles) {
    Backup-IfExists $file.Dest
    Copy-Item "$RepoRoot\config\$($file.Name)" -Destination $file.Dest -Force
    Write-Host "Copied $($file.Name)" -ForegroundColor Green
}

# Remove extensions that shouldn't be installed (e.g. integrations that are
# only used elsewhere, like Claude Code's MCP servers). Declarative and
# idempotent: no-op once the extension is already gone.
Write-Host "`nStep 3: Removing disabled extensions..." -ForegroundColor Yellow
$removedExtensionsPath = "$RepoRoot\config\removed-extensions.json"
if (Test-Path $removedExtensionsPath) {
    $removedExtensions = Get-Content $removedExtensionsPath | ConvertFrom-Json
    foreach ($extId in $removedExtensions) {
        $installedPath = "$ZedExtensionsDir\$extId"
        $workPath = "$ZedExtensionsWorkDir\$extId"
        if (Test-Path $installedPath) {
            Remove-Item $installedPath -Recurse -Force
            Write-Host "Removed extension: $extId" -ForegroundColor Green
        }
        if (Test-Path $workPath) {
            Remove-Item $workPath -Recurse -Force
        }
    }
}

# Windows-only patch: point the integrated terminal at WSL.
# This is the single platform-specific field (see design decision 4) -
# everything else in settings.json is shared as-is across platforms.
Write-Host "`nStep 4: Applying Windows-specific settings..." -ForegroundColor Yellow
$settings = Get-Content $ZedSettingsFile -Raw | ConvertFrom-Json
if (-not $settings.terminal) {
    $settings | Add-Member -MemberType NoteProperty -Name terminal -Value ([PSCustomObject]@{})
}
$settings.terminal | Add-Member -MemberType NoteProperty -Name shell -Value ([PSCustomObject]@{ program = "wsl.exe" }) -Force
$settings | ConvertTo-Json -Depth 20 | Set-Content $ZedSettingsFile
Write-Host "Set terminal.shell.program = wsl.exe" -ForegroundColor Green

# Sync theme extension
Write-Host "`nStep 5: Syncing theme extension..." -ForegroundColor Yellow

$manifestPath = "$RepoRoot\theme\manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    $themeRepo = $manifest.repo
    $extensionId = $manifest.extension_id

    $themeCacheDir = "$env:TEMP\zed-theme-sync"
    $themeInstallDir = "$ZedExtensionsDir\$extensionId"

    # If the cache points at a different repo than configured, drop it so we
    # don't silently pull/mirror the wrong theme.
    if (Test-Path $themeCacheDir) {
        $existingRemote = git -C $themeCacheDir remote get-url origin 2>$null
        if ($existingRemote -ne $themeRepo) {
            Write-Host "Theme repo changed, dropping stale cache..." -ForegroundColor Cyan
            Remove-Item $themeCacheDir -Recurse -Force
        }
    }

    # Clone or update theme repository
    if (Test-Path $themeCacheDir) {
        Write-Host "Updating theme repository..." -ForegroundColor Cyan
        git -C $themeCacheDir pull --ff-only 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to update theme, re-cloning..." -ForegroundColor Yellow
            Remove-Item $themeCacheDir -Recurse -Force
            git clone $themeRepo $themeCacheDir
        }
    } else {
        Write-Host "Cloning theme repository..." -ForegroundColor Cyan
        git clone $themeRepo $themeCacheDir
    }

    # Mirror theme to extensions directory. /MIR already deletes stale files
    # on the destination, so no manual pre-delete is needed - and skipping it
    # lets robocopy make this an incremental (near-instant) sync on reruns.
    Write-Host "Mirroring theme to extensions directory..." -ForegroundColor Cyan
    robocopy $themeCacheDir $themeInstallDir /MIR /XD .git /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Host "Error: Failed to sync theme (robocopy exit code $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }

    Write-Host "Theme synced successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: manifest.json not found" -ForegroundColor Yellow
}

Write-Host "`nZed bootstrap completed successfully!" -ForegroundColor Green
Write-Host "Please restart Zed to apply all changes." -ForegroundColor Cyan

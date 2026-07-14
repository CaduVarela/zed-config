# Pushes local Zed config changes back into the repo, commits, and pushes.

param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = "Stop"

Write-Host "Pushing local Zed config to repo..." -ForegroundColor Green

. "$PSScriptRoot\paths.ps1"

$configFiles = @(
    @{ Name = "settings.json"; Src = $ZedSettingsFile },
    @{ Name = "keymap.json"; Src = $ZedKeymapFile },
    @{ Name = "AGENTS.md"; Src = $ZedAgentsFile }
)

foreach ($file in $configFiles) {
    $dest = "$RepoRoot\config\$($file.Name)"
    if (Test-Path $file.Src) {
        Copy-Item $file.Src -Destination $dest -Force
        Write-Host "Copied $($file.Name) from live config" -ForegroundColor Cyan
    } else {
        Write-Host "Skipping $($file.Name) (not found at $($file.Src))" -ForegroundColor Yellow
    }
}

# Strip the Windows-only terminal.shell patch (injected at install time, see
# install.ps1 Step 4) so it doesn't get committed back into the
# cross-platform settings.json.
$settingsPath = "$RepoRoot\config\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($settings.terminal -and ($settings.terminal.PSObject.Properties.Name -contains "shell")) {
        $settings.terminal.PSObject.Properties.Remove("shell")
        $settings | ConvertTo-Json -Depth 20 | Set-Content $settingsPath
        Write-Host "Stripped Windows-only terminal.shell before committing" -ForegroundColor Cyan
    }
}

Set-Location $RepoRoot

$changed = git status --porcelain -- config/settings.json config/keymap.json config/AGENTS.md
if (-not $changed) {
    Write-Host "Already in sync - nothing to push." -ForegroundColor Green
    exit 0
}

Write-Host "`nChanges to sync:" -ForegroundColor Yellow
git --no-pager diff -- config/settings.json config/keymap.json config/AGENTS.md
git --no-pager diff --cached -- config/settings.json config/keymap.json config/AGENTS.md

git add config/settings.json config/keymap.json config/AGENTS.md
git commit -m "chore: sync personal config from $env:COMPUTERNAME"

Write-Host "`nPushing to remote..." -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: commit created locally but push failed (check your git remote auth)." -ForegroundColor Red
    exit 1
}
Write-Host "Push complete." -ForegroundColor Green

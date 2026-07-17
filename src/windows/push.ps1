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

# Extract Zed's MCP server configs (context_servers) into config/mcp/<name>.json
# as the source of truth, and strip context_servers from settings.json so it
# isn't duplicated. Deletes files for servers no longer present live, mirroring
# the theme sync's "repo always matches what's live" behavior.
$mcpDir = "$RepoRoot\config\mcp"
if (-not (Test-Path $mcpDir)) {
    New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
}

if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $liveKeys = @()
    if ($settings.context_servers) {
        $liveKeys = $settings.context_servers.PSObject.Properties.Name
        foreach ($key in $liveKeys) {
            $destFile = "$mcpDir\$key.json"
            $settings.context_servers.$key | ConvertTo-Json -Depth 20 | Set-Content $destFile
            Write-Host "Synced MCP config: $key.json" -ForegroundColor Cyan
        }
    }

    Get-ChildItem -Path $mcpDir -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($liveKeys -notcontains $_.BaseName) {
            Remove-Item $_.FullName -Force
            Write-Host "Removed stale MCP config: $($_.Name)" -ForegroundColor Yellow
        }
    }

    if ($settings.PSObject.Properties.Name -contains "context_servers") {
        $settings.PSObject.Properties.Remove("context_servers")
    }
    $settings | ConvertTo-Json -Depth 20 | Set-Content $settingsPath
}

Set-Location $RepoRoot

$changed = git status --porcelain -- config/settings.json config/keymap.json config/AGENTS.md config/mcp
if (-not $changed) {
    Write-Host "Already in sync - nothing to push." -ForegroundColor Green
    exit 0
}

Write-Host "`nChanges to sync:" -ForegroundColor Yellow
git --no-pager diff -- config/settings.json config/keymap.json config/AGENTS.md config/mcp
git --no-pager diff --cached -- config/settings.json config/keymap.json config/AGENTS.md config/mcp

git add config/settings.json config/keymap.json config/AGENTS.md config/mcp
git commit -m "chore: sync personal config from $env:COMPUTERNAME"

Write-Host "`nPushing to remote..." -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: commit created locally but push failed (check your git remote auth)." -ForegroundColor Red
    exit 1
}
Write-Host "Push complete." -ForegroundColor Green

# Pushes local Zed config changes back into the repo, commits, and pushes.

param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = "Stop"

Write-Host "Pushing local Zed config to repo..." -ForegroundColor Green

. "$PSScriptRoot\paths.ps1"
. "$PSScriptRoot\json.ps1"

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

$settingsPath = "$RepoRoot\config\settings.json"
$mcpDir = "$RepoRoot\config\mcp"
$settings = Read-JsonFile $settingsPath

# Strip the Windows-only terminal.shell patch (injected at install time, see
# install.ps1 Step 4) and machine-specific state (recent WSL/SSH projects) so
# they don't get committed back into the cross-platform settings.json.
if ($settings.terminal -and ($settings.terminal.PSObject.Properties.Name -contains "shell")) {
    $settings.terminal.PSObject.Properties.Remove("shell")
    Write-Host "Stripped Windows-only terminal.shell before committing" -ForegroundColor Cyan
}
foreach ($key in @("wsl_connections", "ssh_connections")) {
    if ($settings.PSObject.Properties.Name -contains $key) {
        $settings.PSObject.Properties.Remove($key)
        Write-Host "Stripped machine-specific $key before committing" -ForegroundColor Cyan
    }
}

# Extract Zed's MCP server configs (context_servers) into config/mcp/<name>.json
# as the source of truth, and strip context_servers from settings.json so it
# isn't duplicated. Disabled servers are left out. Deletes files for servers no
# longer present (or enabled) live, mirroring the theme sync's "repo always
# matches what's live" behavior.
if (-not (Test-Path $mcpDir)) {
    New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
}

$liveKeys = @()
if ($settings.context_servers) {
    foreach ($prop in $settings.context_servers.PSObject.Properties) {
        if ($prop.Value.enabled -eq $false) {
            Write-Host "Skipping disabled MCP config: $($prop.Name)" -ForegroundColor Yellow
            continue
        }
        $liveKeys += $prop.Name
        Write-JsonFile "$mcpDir\$($prop.Name).json" $prop.Value
        Write-Host "Synced MCP config: $($prop.Name).json" -ForegroundColor Cyan
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

# Add extensions installed through the Zed UI to auto_install_extensions, so
# other machines get them too. Skips the personal theme (synced separately)
# and anything in removed-extensions.json. Never removes entries: an extension
# missing here may still be wanted elsewhere - uninstall via
# removed-extensions.json instead.
$removedExtensions = @()
$removedExtensionsPath = "$RepoRoot\config\removed-extensions.json"
if (Test-Path $removedExtensionsPath) {
    # PowerShell 5.1's ConvertFrom-Json emits a JSON array as one object; the
    # ForEach-Object unrolls it so -contains checks the ids, not the array.
    $removedExtensions = @(Read-JsonFile $removedExtensionsPath | ForEach-Object { $_ })
}
$themeExtensionId = $null
$manifestPath = "$RepoRoot\theme\manifest.json"
if (Test-Path $manifestPath) {
    $themeExtensionId = (Read-JsonFile $manifestPath).extension_id
}

if (Test-Path $ZedExtensionsDir) {
    $autoInstall = [ordered]@{}
    if ($settings.auto_install_extensions) {
        foreach ($prop in $settings.auto_install_extensions.PSObject.Properties) {
            $autoInstall[$prop.Name] = $prop.Value
        }
    }
    Get-ChildItem -Path $ZedExtensionsDir -Directory | ForEach-Object {
        $extId = $_.Name
        if ($extId -eq $themeExtensionId -or $removedExtensions -contains $extId -or $autoInstall.Contains($extId)) {
            return
        }
        $autoInstall[$extId] = $true
        Write-Host "Added installed extension to auto_install_extensions: $extId" -ForegroundColor Cyan
    }
    $sorted = [ordered]@{}
    foreach ($k in ($autoInstall.Keys | Sort-Object)) { $sorted[$k] = $autoInstall[$k] }
    if ($settings.PSObject.Properties.Name -contains "auto_install_extensions") {
        $settings.auto_install_extensions = $sorted
    } else {
        $settings | Add-Member -MemberType NoteProperty -Name auto_install_extensions -Value $sorted
    }
}

Write-JsonFile $settingsPath $settings

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

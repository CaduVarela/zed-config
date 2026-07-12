# Install prerequisites on Windows: Git and Zed

param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

Write-Host "Installing prerequisites on Windows..." -ForegroundColor Green

# Check if winget is available
$wingetPath = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetPath) {
    Write-Host "Error: winget not found. Please install App Installer from Microsoft Store." -ForegroundColor Red
    exit 1
}

# Install Git if not present
Write-Host "Checking Git..."
$gitPath = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitPath) {
    Write-Host "Installing Git..." -ForegroundColor Cyan
    winget install -e --id Git.Git -h --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Git installation had issues, but continuing..." -ForegroundColor Yellow
    }
} else {
    Write-Host "Git already installed" -ForegroundColor Green
}

# Install Zed if not present
Write-Host "Checking Zed..."
$zedPath = Get-Command zed -ErrorAction SilentlyContinue
if (-not $zedPath) {
    Write-Host "Installing Zed..." -ForegroundColor Cyan
    winget install -e --id ZedIndustries.Zed -h --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to install Zed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Zed already installed" -ForegroundColor Green
}

Write-Host "Prerequisites installed successfully" -ForegroundColor Green

# Install prerequisites on Windows: Git and Zed

Write-Host "Installing prerequisites on Windows..." -ForegroundColor Green

# Check if winget is available
$wingetPath = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetPath) {
    Write-Host "Error: winget not found. Please install App Installer from Microsoft Store." -ForegroundColor Red
    exit 1
}

$prerequisites = @(
    @{ Command = "git"; WingetId = "Git.Git"; Label = "Git"; Required = $false },
    @{ Command = "zed"; WingetId = "ZedIndustries.Zed"; Label = "Zed"; Required = $true }
)

foreach ($prereq in $prerequisites) {
    Write-Host "Checking $($prereq.Label)..."
    $found = Get-Command $prereq.Command -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "$($prereq.Label) already installed" -ForegroundColor Green
        continue
    }

    Write-Host "Installing $($prereq.Label)..." -ForegroundColor Cyan
    winget install -e --id $prereq.WingetId -h --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        if ($prereq.Required) {
            Write-Host "Error: Failed to install $($prereq.Label)" -ForegroundColor Red
            exit 1
        }
        Write-Host "Warning: $($prereq.Label) installation had issues, but continuing..." -ForegroundColor Yellow
    }
}

Write-Host "Prerequisites installed successfully" -ForegroundColor Green

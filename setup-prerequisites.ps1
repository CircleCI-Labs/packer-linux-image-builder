# Setup Prerequisites for Windows
$ErrorActionPreference = "Stop"

Write-Host "-------------------------------------------" -ForegroundColor Cyan
Write-Host "     Performing System Updates" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor Cyan

# Install Windows Updates
Write-Host "Installing Windows Updates (this may take a while)..."
Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
Import-Module PSWindowsUpdate
Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Configuring Windows Time (NTP)" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

# Configure Windows Time service (equivalent to NTP)
Set-Service w32time -StartupType Automatic
Start-Service w32time
w32tm /config /manualpeerlist:"time.windows.com,0x8" /syncfromflags:manual /reliable:yes /update
w32tm /resync

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing Git" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

# Install Chocolatey if not already installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey package manager..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
}

choco install git -y

Write-Host "Git version:" -ForegroundColor Yellow
git --version

Write-Host ""
Write-Host "Prerequisites setup complete!" -ForegroundColor Green

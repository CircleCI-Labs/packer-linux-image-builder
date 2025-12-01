# Setup Docker for Windows
# Requires: Windows Server 2019/2022 or Windows 10/11 Pro/Enterprise
$ErrorActionPreference = "Stop"

Write-Host "-------------------------------------------" -ForegroundColor Cyan
Write-Host "     Performing System Updates" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor Cyan

# Install Chocolatey if not already installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey package manager..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
}

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing Git" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan
choco install git -y

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Configuring Windows Time (NTP)" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan
# Configure Windows Time service (equivalent to NTP)
Set-Service w32time -StartupType Automatic
Start-Service w32time
w32tm /config /manualpeerlist:"time.windows.com,0x8" /syncfromflags:manual /reliable:yes /update
w32tm /resync

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing Docker" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

# Install Docker via Chocolatey
choco install docker-desktop -y

# Alternative: Install Docker Engine directly (for Windows Server)
# Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
# Install-Package -Name docker -ProviderName DockerMsftProvider -Force

Write-Host "Adding current user to docker-users group..." -ForegroundColor Yellow
Add-LocalGroupMember -Group "docker-users" -Member $env:USERNAME -ErrorAction SilentlyContinue

Write-Host "Checking Docker version and info..." -ForegroundColor Yellow
docker --version
docker info

Write-Host "Installing Docker Compose..." -ForegroundColor Cyan
# Docker Desktop includes Docker Compose, but we'll ensure it's available
# Compose v2 is included with Docker Desktop, but we can also install standalone
choco install docker-compose -y

Write-Host "Creating circleci user..." -ForegroundColor Cyan
$Password = ConvertTo-SecureString "TempPassword123!" -AsPlainText -Force
try {
    New-LocalUser -Name "circleci" -Password $Password -FullName "CircleCI User" -Description "CircleCI Build User" -ErrorAction Stop
    Write-Host "User 'circleci' created successfully"
} catch {
    Write-Host "User 'circleci' may already exist: $_" -ForegroundColor Yellow
}

# Add circleci to Administrators group (equivalent to sudo ALL)
Add-LocalGroupMember -Group "Administrators" -Member "circleci" -ErrorAction SilentlyContinue

# Add circleci to docker-users group
Add-LocalGroupMember -Group "docker-users" -Member "circleci" -ErrorAction SilentlyContinue

Write-Host "Verifying installations..." -ForegroundColor Cyan
Write-Host "Docker Compose version:" -ForegroundColor Yellow
docker-compose --version
Write-Host "Git version:" -ForegroundColor Yellow
git --version

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "NOTE: A system restart may be required for Docker to function properly." -ForegroundColor Yellow
Write-Host "You may need to set a permanent password for the 'circleci' user." -ForegroundColor Yellow

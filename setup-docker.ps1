# Setup Docker for Windows
# Installs: Git, Docker Desktop, docker-compose
# Creates: circleci user with admin and docker-users group membership
# Requires: Windows Server 2019/2022 or Windows 10/11 Pro/Enterprise
$ErrorActionPreference = "Stop"

Write-Host "Creating required directories..." -ForegroundColor Cyan
New-Item -Path "C:\CircleCI\Temp" -ItemType Directory -Force | Out-Null
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Write-Host "Directories created: C:\CircleCI\Temp and C:\Temp" -ForegroundColor Green

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

# Refresh environment variables after Git installation
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

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

Write-Host "Installing Docker Compose..." -ForegroundColor Cyan
# Docker Desktop includes Docker Compose, but we'll ensure it's available
# Compose v2 is included with Docker Desktop, but we can also install standalone
choco install docker-compose -y

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

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

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "NOTE: Docker installation requires a system restart to function properly." -ForegroundColor Yellow
Write-Host "Docker and docker-compose commands will be available after restart." -ForegroundColor Yellow
Write-Host "You may need to set a permanent password for the 'circleci' user." -ForegroundColor Yellow

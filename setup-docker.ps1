# Setup Docker for Windows
# Installs: Git, Docker Desktop 4.36.x (Engine 28.x), docker-compose, 7zip, gzip, sysinternals
# Creates: circleci and circleci-admin users with admin and docker-users group membership
# Password: TempPassword123! (should be changed)
# Directories: C:\CircleCI\Temp, C:\Temp
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

# Add Git Unix tools to PATH (for xargs, etc.)
Write-Host "Adding Git Unix tools to system PATH..."
$gitUnixToolsPath = "C:\Program Files\Git\usr\bin"
if (Test-Path $gitUnixToolsPath) {
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$gitUnixToolsPath*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$gitUnixToolsPath", "Machine")
        Write-Host "Git Unix tools added to system PATH" -ForegroundColor Green
    }
} else {
    Write-Host "WARNING: Git Unix tools directory not found at $gitUnixToolsPath" -ForegroundColor Yellow
}

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing Additional Tools" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "Installing 7zip, gzip, and sysinternals..."
choco install 7zip -y
choco install gzip -y
choco install sysinternals -y

# Refresh environment variables after all tool installations
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing Docker (Engine 28.x)" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

# Install Docker Desktop 4.36.x which includes Docker Engine 28.x
# Note: Docker Desktop 4.37+ includes Engine 29.x, so we pin to 4.36.x
Write-Host "Installing Docker Desktop 4.36.x (includes Docker Engine 28.x)..."
choco install docker-desktop --version=4.36.0 -y --allow-downgrade

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

Write-Host "Creating circleci and circleci-admin users..." -ForegroundColor Cyan
$Password = ConvertTo-SecureString "TempPassword123!" -AsPlainText -Force

# Create circleci user
try {
    New-LocalUser -Name "circleci" -Password $Password -FullName "CircleCI User" -Description "CircleCI Build User" -PasswordNeverExpires:$true -ErrorAction Stop
    Write-Host "User 'circleci' created successfully"
} catch {
    Write-Host "User 'circleci' may already exist: $_" -ForegroundColor Yellow
}

# Create circleci-admin user
try {
    New-LocalUser -Name "circleci-admin" -Password $Password -FullName "CircleCI Admin User" -Description "CircleCI Admin Build User" -PasswordNeverExpires:$true -ErrorAction Stop
    Write-Host "User 'circleci-admin' created successfully"
} catch {
    Write-Host "User 'circleci-admin' may already exist: $_" -ForegroundColor Yellow
}

# Add circleci to Administrators group (equivalent to sudo ALL)
Add-LocalGroupMember -Group "Administrators" -Member "circleci" -ErrorAction SilentlyContinue
Write-Host "Added 'circleci' to Administrators group"

# Add circleci to docker-users group
Add-LocalGroupMember -Group "docker-users" -Member "circleci" -ErrorAction SilentlyContinue
Write-Host "Added 'circleci' to docker-users group"

# Add circleci-admin to Administrators group
Add-LocalGroupMember -Group "Administrators" -Member "circleci-admin" -ErrorAction SilentlyContinue
Write-Host "Added 'circleci-admin' to Administrators group"

# Add circleci-admin to docker-users group
Add-LocalGroupMember -Group "docker-users" -Member "circleci-admin" -ErrorAction SilentlyContinue
Write-Host "Added 'circleci-admin' to docker-users group"

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "NOTE: Docker installation requires a system restart to function properly." -ForegroundColor Yellow
Write-Host "Docker Engine 28.x and docker-compose commands will be available after restart." -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow
Write-Host "Users created:" -ForegroundColor Yellow
Write-Host "  - circleci (Password: TempPassword123!)" -ForegroundColor Yellow
Write-Host "  - circleci-admin (Password: TempPassword123!)" -ForegroundColor Yellow
Write-Host "Both users have Administrator and docker-users permissions." -ForegroundColor Yellow
Write-Host "IMPORTANT: Change these passwords for production use!" -ForegroundColor Red

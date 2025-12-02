# Setup Windows AMI for CircleCI Build Agent
#
# This script configures a complete CircleCI build agent environment including:
#   - System: TLS 1.2, PowerShell execution policy, .NET Framework 4.8
#   - Git 2.46.2, Git-LFS 3.5.1
#   - Docker CE, docker-compose
#   - 7zip 24.8.0, gzip 1.3.12, sysinternals 2024.7.23
#   - circleci and circleci-admin users (Administrators)
#   - Required directories: C:\CircleCI\Temp, C:\Temp
#
# Password: gFo8.UbL-@Ln*q-m (matches working repo)
# Requires: Windows Server 2019/2022
# Versions match windows2022/software.yml
$ErrorActionPreference = "Stop"

Write-Host "Creating required directories..." -ForegroundColor Cyan
New-Item -Path "C:\CircleCI\Temp" -ItemType Directory -Force | Out-Null
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
Write-Host "Directories created: C:\CircleCI\Temp and C:\Temp" -ForegroundColor Green

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Configuring System Settings" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

# Enable TLS 1.2 for secure downloads
Write-Host "Enabling TLS 1.2..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Set PowerShell execution policy
Write-Host "Setting PowerShell execution policy..."
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

Write-Host "System configuration complete" -ForegroundColor Green

# Install Chocolatey if not already installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey package manager..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
}

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing .NET Framework" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan
# Install .NET Framework 4.8 (includes System.Web assembly required by CircleCI agent)
choco install dotnet-4.8 -y
Write-Host ".NET Framework 4.8 installed" -ForegroundColor Green

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing Git & Git-LFS" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan
# Pin to versions from working repo (windows2022/software.yml)
choco install git --version=2.46.2 -y
choco install git-lfs --version=3.5.1 -y

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
Write-Host "Installing 7zip, gzip, and sysinternals (pinned versions)..."
# Pin to versions from working repo (windows2022/software.yml)
choco install 7zip.portable --version=24.8.0 -y
choco install gzip --version=1.3.12 -y
choco install sysinternals --version=2024.7.23 -y

# Refresh environment variables after all tool installations
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing Docker CE" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

# Install Docker CE using Microsoft's official script (matches working repo)
Write-Host "Downloading Docker CE installer..."
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -OutFile "$env:TEMP\install-docker-ce.ps1"

Write-Host "Installing Docker CE..."
& "$env:TEMP\install-docker-ce.ps1"

# Clean up installer
Remove-Item "$env:TEMP\install-docker-ce.ps1" -Force -ErrorAction SilentlyContinue

Write-Host "Docker CE installation complete" -ForegroundColor Green

Write-Host "Installing Docker Compose..." -ForegroundColor Cyan
choco install docker-compose -y

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "Creating circleci and circleci-admin users..." -ForegroundColor Cyan
$Password = ConvertTo-SecureString "gFo8.UbL-@Ln*q-m" -AsPlainText -Force

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

# Add circleci-admin to Administrators group
Add-LocalGroupMember -Group "Administrators" -Member "circleci-admin" -ErrorAction SilentlyContinue
Write-Host "Added 'circleci-admin' to Administrators group"

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "NOTE: Docker CE installation requires a system restart to function properly." -ForegroundColor Yellow
Write-Host "Docker CE and docker-compose commands will be available after restart." -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow
Write-Host "Users created:" -ForegroundColor Yellow
Write-Host "  - circleci (Password: gFo8.UbL-@Ln*q-m)" -ForegroundColor Yellow
Write-Host "  - circleci-admin (Password: gFo8.UbL-@Ln*q-m)" -ForegroundColor Yellow
Write-Host "Both users have Administrator permissions." -ForegroundColor Yellow
Write-Host "IMPORTANT: Change these passwords for production use!" -ForegroundColor Red

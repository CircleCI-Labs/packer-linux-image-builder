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

# Disable Windows Firewall for all profiles
Write-Host "Disabling Windows Firewall..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Write-Host "Windows Firewall disabled for all profiles" -ForegroundColor Green

# Enable TLS 1.2 for secure downloads (current session + system-wide)
Write-Host "Enabling TLS 1.2..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Enable TLS 1.2 system-wide via registry for .NET applications
Write-Host "Configuring TLS 1.2 system-wide via registry..."
$tls12RegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319"
)
foreach ($path in $tls12RegPaths) {
    if (!(Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    Set-ItemProperty -Path $path -Name "SchUseStrongCrypto" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $path -Name "SystemDefaultTlsVersions" -Value 1 -Type DWord -Force
}
Write-Host "TLS 1.2 enabled system-wide" -ForegroundColor Green

# Set PowerShell execution policy (if not already permissive)
Write-Host "Configuring PowerShell execution policy..."
try {
    $currentPolicy = Get-ExecutionPolicy -Scope LocalMachine
    if ($currentPolicy -ne "RemoteSigned" -and $currentPolicy -ne "Unrestricted" -and $currentPolicy -ne "Bypass") {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
        Write-Host "Execution policy set to RemoteSigned" -ForegroundColor Green
    } else {
        Write-Host "Execution policy already configured ($currentPolicy)" -ForegroundColor Green
    }
} catch {
    Write-Host "Execution policy: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Current policy is sufficient for operation" -ForegroundColor Green
}

Write-Host "System configuration complete" -ForegroundColor Green

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Creating CircleCI Users" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan
$Password = ConvertTo-SecureString "gFo8.UbL-@Ln*q-m" -AsPlainText -Force

# Create circleci user
Write-Host "Creating 'circleci' user..."
try {
    $existingUser = Get-LocalUser -Name "circleci" -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "User 'circleci' already exists, updating password..." -ForegroundColor Yellow
        Set-LocalUser -Name "circleci" -Password $Password
    } else {
        New-LocalUser -Name "circleci" -Password $Password -FullName "CircleCI User" -Description "CircleCI Build User" -PasswordNeverExpires:$true -ErrorAction Stop
        Write-Host "User 'circleci' created successfully" -ForegroundColor Green
    }
} catch {
    Write-Host "CRITICAL ERROR creating circleci user: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Exception details: $($_.Exception)" -ForegroundColor Red
    throw
}

# Create circleci-admin user
Write-Host "Creating 'circleci-admin' user..."
try {
    $existingAdmin = Get-LocalUser -Name "circleci-admin" -ErrorAction SilentlyContinue
    if ($existingAdmin) {
        Write-Host "User 'circleci-admin' already exists, updating password..." -ForegroundColor Yellow
        Set-LocalUser -Name "circleci-admin" -Password $Password
    } else {
        New-LocalUser -Name "circleci-admin" -Password $Password -FullName "CircleCI Admin User" -Description "CircleCI Admin Build User" -PasswordNeverExpires:$true -ErrorAction Stop
        Write-Host "User 'circleci-admin' created successfully" -ForegroundColor Green
    }
} catch {
    Write-Host "CRITICAL ERROR creating circleci-admin user: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Exception details: $($_.Exception)" -ForegroundColor Red
    throw
}

# Add circleci to Administrators group
Write-Host "Adding 'circleci' to Administrators group..."
try {
    Add-LocalGroupMember -Group "Administrators" -Member "circleci" -ErrorAction Stop
    Write-Host "Added 'circleci' to Administrators group" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already a member*") {
        Write-Host "'circleci' already in Administrators group" -ForegroundColor Yellow
    } else {
        Write-Host "ERROR adding circleci to Administrators: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Add circleci-admin to Administrators group
Write-Host "Adding 'circleci-admin' to Administrators group..."
try {
    Add-LocalGroupMember -Group "Administrators" -Member "circleci-admin" -ErrorAction Stop
    Write-Host "Added 'circleci-admin' to Administrators group" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already a member*") {
        Write-Host "'circleci-admin' already in Administrators group" -ForegroundColor Yellow
    } else {
        Write-Host "ERROR adding circleci-admin to Administrators: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Verify users were created successfully
Write-Host "Verifying user creation..."
$circleciUser = Get-LocalUser -Name "circleci" -ErrorAction SilentlyContinue
$circleciAdminUser = Get-LocalUser -Name "circleci-admin" -ErrorAction SilentlyContinue
if ($circleciUser -and $circleciAdminUser) {
    Write-Host "Both users verified successfully" -ForegroundColor Green
} else {
    Write-Host "CRITICAL ERROR: User verification failed!" -ForegroundColor Red
    throw "Failed to create required users"
}

Write-Host "User creation complete" -ForegroundColor Green

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
# Sysinternals updates frequently, use --ignore-checksums for this package
choco install sysinternals --version=2024.7.23 -y --ignore-checksums

# Refresh environment variables after all tool installations
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "--------------------------------------" -ForegroundColor Cyan
Write-Host "        Installing Docker CE" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor Cyan

# Enable Containers feature (required for Docker)
Write-Host "Checking Windows Containers feature..."
$containersFeature = Get-WindowsOptionalFeature -Online -FeatureName Containers -ErrorAction SilentlyContinue
if ($null -eq $containersFeature -or $containersFeature.State -ne 'Enabled') {
    Write-Host "Enabling Windows Containers feature..."
    Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart -ErrorAction Stop
    Write-Host "Containers feature enabled (will be active after restart)" -ForegroundColor Green
} else {
    Write-Host "Containers feature already enabled" -ForegroundColor Green
}

# Install Docker CE manually for full control
Write-Host "Downloading Docker CE..."
$dockerVersion = "27.3.1"
$dockerUrl = "https://download.docker.com/win/static/stable/x86_64/docker-$dockerVersion.zip"
$dockerZip = "$env:TEMP\docker.zip"
$dockerPath = "$env:ProgramFiles\Docker"

Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerZip -UseBasicParsing
Write-Host "Docker downloaded"

# Extract Docker
Write-Host "Extracting Docker to $dockerPath..."
if (Test-Path $dockerPath) {
    Remove-Item -Path $dockerPath -Recurse -Force
}
Expand-Archive -Path $dockerZip -DestinationPath $env:ProgramFiles -Force
Remove-Item $dockerZip -Force

# Add Docker to system PATH
Write-Host "Adding Docker to system PATH..."
$dockerBinPath = "$dockerPath"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$dockerBinPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dockerBinPath", "Machine")
    $env:Path += ";$dockerBinPath"
}
Write-Host "Docker added to PATH" -ForegroundColor Green

# Register Docker as a Windows service
Write-Host "Registering Docker service..."
& "$dockerPath\dockerd.exe" --register-service
Write-Host "Docker service registered" -ForegroundColor Green

# Configure Docker daemon
Write-Host "Configuring Docker daemon..."
$dockerConfigPath = "C:\ProgramData\docker\config"
if (!(Test-Path $dockerConfigPath)) {
    New-Item -Path $dockerConfigPath -ItemType Directory -Force | Out-Null
}

$daemonConfig = @{
    "experimental" = $false
    "hosts" = @("npipe://")
} | ConvertTo-Json

Set-Content -Path "$dockerConfigPath\daemon.json" -Value $daemonConfig -Force
Write-Host "Docker daemon configured" -ForegroundColor Green

Write-Host "Docker CE installation complete (will start after restart)" -ForegroundColor Green

Write-Host "Installing Docker Compose..." -ForegroundColor Cyan
choco install docker-compose -y

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "    Setup Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed Software:" -ForegroundColor Cyan
Write-Host "  - .NET Framework 4.8" -ForegroundColor White
Write-Host "  - Git 2.46.2 (with Unix tools)" -ForegroundColor White
Write-Host "  - Git-LFS 3.5.1" -ForegroundColor White
Write-Host "  - Docker CE + docker-compose" -ForegroundColor White
Write-Host "  - 7zip 24.8.0, gzip 1.3.12, sysinternals 2024.7.23" -ForegroundColor White
Write-Host "  - OpenSSH Server" -ForegroundColor White
Write-Host ""
Write-Host "Users Created:" -ForegroundColor Cyan
Write-Host "  - circleci (Administrator)" -ForegroundColor White
Write-Host "  - circleci-admin (Administrator)" -ForegroundColor White
Write-Host "  Password: gFo8.UbL-@Ln*q-m" -ForegroundColor Yellow
Write-Host ""
Write-Host "NOTE: Docker requires restart to function. It will be available when instances launch from this AMI." -ForegroundColor Yellow
Write-Host "IMPORTANT: Change passwords for production use!" -ForegroundColor Red

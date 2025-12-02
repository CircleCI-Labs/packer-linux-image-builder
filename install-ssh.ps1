$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "   Installing and Configuring SSH" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Method 1: Try using Windows Optional Features via DISM (most reliable)
Write-Host "Installing OpenSSH Server via DISM..." -ForegroundColor Yellow
try {
    $dismResult = dism.exe /online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OpenSSH installed successfully via DISM" -ForegroundColor Green
    } else {
        throw "DISM failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "DISM method failed, trying Chocolatey..." -ForegroundColor Yellow

    # Ensure Chocolatey is available
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    # Install OpenSSH via Chocolatey
    choco install openssh -y --params "/SSHServerFeature"
    Write-Host "OpenSSH installed via Chocolatey" -ForegroundColor Green
}

# Ensure sshd service exists and start it
Write-Host "Starting SSH service..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

if (Get-Service -Name sshd -ErrorAction SilentlyContinue) {
    Start-Service sshd -ErrorAction SilentlyContinue
    Set-Service -Name sshd -StartupType 'Automatic'
    Write-Host "SSH service started and set to automatic" -ForegroundColor Green
} else {
    Write-Host "WARNING: sshd service not found. Will be available after reboot." -ForegroundColor Yellow
}

# Configure SSH
Write-Host "Configuring SSH settings..." -ForegroundColor Yellow

# Ensure SSH directory exists
$sshConfigPath = "$env:PROGRAMDATA\ssh"
if (!(Test-Path $sshConfigPath)) {
    New-Item -Path $sshConfigPath -ItemType Directory -Force | Out-Null
}

$sshdConfig = @"
# This is the sshd server system-wide configuration file.
# Config matches windows2022/provision-scripts/install-ssh-2022.ps1

ListenAddress 0.0.0.0
Port 22

Protocol 2 # disable legacy support for security reasons
StrictModes no # make sure sshd checks file modes and ownership before accepting logins
UsePrivilegeSeparation sandbox
Compression no
UseDNS no

# TCP keep alive messages are spoofable, use client keep alive instead
TCPKeepAlive no
ClientAliveInterval 300
ClientAliveCountMax 3

AuthorizedKeysFile C:/Users/%u/.ssh/authorized_keys
PubkeyAuthentication yes
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

Ciphers aes256-gcm@openssh.com,aes256-ctr,chacha20-poly1305@openssh.com
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
MACs hmac-sha2-256,hmac-sha2-512

# never use host-based auth
IgnoreRhosts yes
IgnoreUserKnownHosts yes
HostbasedAuthentication no
RhostsRSAAuthentication no

X11Forwarding no
X11UseLocalhost yes
PermitUserEnvironment yes
AcceptEnv LANG LC_*

# Enable debug logging
# Prior to launching, let's enable debug logging for SSH.
# To view SSH logs, run this on the machine from a terminal:
# Get-Content -Path C:\ProgramData\ssh\Logs\sshd.log -Wait -Tail 0
SyslogFacility LOCAL0
LogLevel DEBUG3

"@

Set-Content "$sshConfigPath\sshd_config" $sshdConfig -Force
Write-Host "SSH configuration updated" -ForegroundColor Green

# Configure firewall
Write-Host "Configuring firewall rule for SSH..." -ForegroundColor Yellow
netsh advfirewall firewall delete rule name="OpenSSH SSH Server (sshd)" protocol=TCP localport=22 2>$null
netsh advfirewall firewall add rule name="OpenSSH SSH Server (sshd)" dir=in action=allow protocol=TCP localport=22
Write-Host "Firewall rule added" -ForegroundColor Green

# Set bash as default shell if Git bash is available
Write-Host "Checking for bash shell..." -ForegroundColor Yellow
$BashCommand = Get-Command "bash.exe" -ErrorAction SilentlyContinue
if ($BashCommand) {
    try {
        New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $BashCommand.Source -PropertyType String -Force | Out-Null
        Write-Host "Default SSH shell set to: $($BashCommand.Source)" -ForegroundColor Green
    } catch {
        Write-Host "Could not set bash as default shell: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "Bash not found - using default PowerShell shell" -ForegroundColor Yellow
}

# Restart SSH service if it's running
if (Get-Service -Name sshd -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Running'}) {
    Write-Host "Restarting SSH service to apply configuration..." -ForegroundColor Yellow
    Restart-Service sshd
    Write-Host "SSH service restarted" -ForegroundColor Green
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "   SSH Installation Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "SSH will be fully operational after instance reboot" -ForegroundColor Yellow

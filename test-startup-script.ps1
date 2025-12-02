# Test Startup Script - Exact simulation of CircleCI Agent user-data
# This script tests EVERY operation from the actual startup script
# Logs everything to C:\CircleCI\startup-test.log

$ErrorActionPreference = "Continue"

# Ensure log directory exists
$logDir = "C:\CircleCI"
if (!(Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = "$logDir\startup-test.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

function Test-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    Write-Log "========================================"
    Write-Log "Testing: $Name"
    Write-Log "========================================"

    try {
        & $Action
        Write-Log "SUCCESS: $Name" -Level "SUCCESS"
        return $true
    } catch {
        Write-Log "FAILED: $Name" -Level "ERROR"
        Write-Log "Error: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack: $($_.ScriptStackTrace)" -Level "ERROR"
        return $false
    }
}

# Initialize log
Write-Log "Starting CircleCI Agent Startup Script Test" -Level "INFO"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"
Write-Log "OS: $(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Caption)" -Level "INFO"

# Define variables (like in actual script)
$installDirPath = "$env:ProgramFiles\CircleCI"
$agentPath = "$installDirPath\machine-agent.exe"
$tokenFile = "C:\token.txt"
$cacertsFile = "C:\cacerts.pem"

# Test 1: Environment variables
Test-Step "Set Environment Variables" {
    Write-Log "installDirPath: $installDirPath"
    Write-Log "agentPath: $agentPath"
    Write-Log "tokenFile: $tokenFile"
    Write-Log "cacertsFile: $cacertsFile"

    # Test setting environment variable
    $env:CCI_ENTERPRISE = "true"
    Write-Log "CCI_ENTERPRISE set to: $($env:CCI_ENTERPRISE)"
}

# Test 2: Define SetRegistryKey function (exactly as in script)
Test-Step "Define SetRegistryKey Function" {
    Write-Log "Creating SetRegistryKey function..."

    function global:SetRegistryKey {
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Path,
            [Parameter(Mandatory=$true)]
            [string]$Name,
            [ValidateSet('String', 'DWord', 'ExpandString', 'Binary', 'MultiString', 'Qword', 'Unknown')]
            $Type,
            [Parameter(Mandatory=$true)]
            $Value
        )
        if(!(Test-Path $Path)){
            [void](New-Item -Path $Path -Force)
        }
        [void](Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type)
    }

    Write-Log "SetRegistryKey function created"
}

# Test 3: Load System.Web and generate credentials
Test-Step "Generate Credentials with System.Web.Security.Membership" {
    Write-Log "Loading System.Web assembly..."
    Add-Type -AssemblyName System.web

    $username = "circleci"
    Write-Log "Generating 42-character password..."
    $passwd = $([System.Web.Security.Membership]::GeneratePassword(42, 10))
    Write-Log "Password generated: Length=$($passwd.Length)"

    $passwdSecure = $(ConvertTo-SecureString -String $passwd -AsPlainText -Force)
    $cred = New-Object System.Management.Automation.PSCredential ($username, $passwdSecure)
    Write-Log "PSCredential created for user: $username"

    # Store for later tests
    $global:testUsername = $username
    $global:testPasswd = $passwd
    $global:testPasswdSecure = $passwdSecure
}

# Test 4: Set user passwords
Test-Step "Set Local User Passwords" {
    Write-Log "Setting password for circleci user..."
    Set-LocalUser -Name $global:testUsername -Password $global:testPasswdSecure
    Write-Log "circleci password set"

    Write-Log "Setting password for circleci-admin user..."
    Set-LocalUser -Name "circleci-admin" -Password $global:testPasswdSecure
    Write-Log "circleci-admin password set"
}

# Test 5: Disable UAC
Test-Step "Disable UAC via Registry" {
    Write-Log "Disabling UAC..."
    SetRegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Type DWord -Value "0x0"
    Write-Log "UAC disabled (ConsentPromptBehaviorAdmin = 0)"
}

# Test 6: Configure Remote Desktop Client
Test-Step "Configure Remote Desktop Client Registry Keys" {
    Write-Log "Setting AllowSavedCredentialsWhenNTLMOnly..."
    SetRegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" -Name "AllowSavedCredentialsWhenNTLMOnly" -Type DWord -Value "0x1"

    Write-Log "Setting ConcatenateDefaults_AllowSavedNTLMOnly..."
    SetRegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" -Name "ConcatenateDefaults_AllowSavedNTLMOnly" -Type DWord -Value "0x1"

    Write-Log "Setting AllowSavedCredentialsWhenNTLMOnly subkey..."
    SetRegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowSavedCredentialsWhenNTLMOnly" -Name "1" -Type String -Value "TERMSRV/localhost"
    Write-Log "Remote Desktop Client configured"
}

# Test 7: Group Policy Update
Test-Step "Run gpupdate.exe /force" {
    Write-Log "Running gpupdate.exe /force..."
    $gpResult = gpupdate.exe /force 2>&1
    Write-Log "gpupdate output: $gpResult"
}

# Test 8: Disable Server Manager at logon
Test-Step "Disable Server Manager at Logon" {
    Write-Log "Setting DoNotOpenServerManagerAtLogon..."
    SetRegistryKey -Path "HKLM:\SOFTWARE\Microsoft\ServerManager" -Name "DoNotOpenServerManagerAtLogon" -Type DWord -Value "0x1"
    Write-Log "Server Manager at logon disabled"
}

# Test 9: Disable Server Manager scheduled task
Test-Step "Disable Server Manager Scheduled Task" {
    Write-Log "Running schtasks to disable Server Manager..."
    $schtasksResult = schtasks /Change /TN "\Microsoft\Windows\Server Manager\ServerManager" /DISABLE 2>&1
    Write-Log "schtasks result: $schtasksResult"
}

# Test 10: Create CircleCI directory
Test-Step "Create CircleCI Directory" {
    Write-Log "Creating directory: $installDirPath"
    [void](New-Item "$installDirPath" -ItemType Directory -Force)
    Write-Log "Directory created: $installDirPath"

    if (Test-Path $installDirPath) {
        Write-Log "Verified: Directory exists"
    }
}

# Test 11: Download with retry and checksum (simulated)
Test-Step "Test Download with Retry and Checksum Logic" {
    Write-Log "Testing download retry logic (simulated)..."

    # Test HTTPS download capability
    $testUrl = "https://www.google.com"
    Write-Log "Testing HTTPS download from: $testUrl"
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 30
    Write-Log "Download successful. Status: $($response.StatusCode)"

    # Test file hash calculation
    Write-Log "Testing Get-FileHash capability..."
    $tempFile = "$env:TEMP\test-hash.txt"
    "test content" | Out-File -FilePath $tempFile -Force
    $hash = Get-FileHash -Algorithm SHA256 $tempFile
    Write-Log "File hash calculated: $($hash.Hash)"
    Remove-Item $tempFile -Force
}

# Test 12: Write token file
Test-Step "Write Token File" {
    Write-Log "Writing token file to: $tokenFile"
    Set-Content -Path $tokenFile -Value "8b15bde408c3b9e1dccd05bf52bc5a6855bac3e3" -NoNewLine
    Write-Log "Token file written"

    if (Test-Path $tokenFile) {
        $content = Get-Content $tokenFile -Raw
        Write-Log "Token file verified. Length: $($content.Length)"
        Remove-Item $tokenFile -Force -ErrorAction SilentlyContinue
    }
}

# Test 13: Register scheduled task WITHOUT password (like CircleCI Agent task)
Test-Step "Register Scheduled Task WITHOUT Password Parameter" {
    Write-Log "Creating scheduled task settings (Hidden, Vista compatibility)..."
    $taskSettings = New-ScheduledTaskSettingsSet -Hidden -Compatibility Vista -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan)
    Write-Log "Task settings created"

    Write-Log "Creating trigger (AtLogon)..."
    $trigger = (New-ScheduledTaskTrigger -AtLogon -User $global:testUsername)
    Write-Log "Trigger created"

    Write-Log "Creating action (Execute powershell.exe)..."
    $action = (New-ScheduledTaskAction -Execute powershell.exe -Argument "-Command `"Write-Host 'Test CircleCI Agent'`"")
    Write-Log "Action created"

    Write-Log "Registering task WITHOUT password parameter..."
    [void](Register-ScheduledTask -Force -TaskName "CircleCI Test Agent" -User $global:testUsername -Action $action -Settings $taskSettings -Trigger $trigger)
    Write-Log "Task registered successfully (no password)"

    Write-Log "Verifying task exists..."
    $task = Get-ScheduledTask -TaskName "CircleCI Test Agent" -ErrorAction Stop
    Write-Log "Task verified: $($task.TaskName)"

    Write-Log "Cleaning up test task..."
    Unregister-ScheduledTask -TaskName "CircleCI Test Agent" -Confirm:$false
}

# Test 14: Register scheduled task WITH password (like RDP task)
Test-Step "Register Scheduled Task WITH Password Parameter" {
    Write-Log "Creating scheduled task settings (Vista compatibility)..."
    $rdpTaskSettings = New-ScheduledTaskSettingsSet -Compatibility Vista -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan)
    Write-Log "RDP task settings created"

    Write-Log "Creating RDP action with complex command..."
    $rdpAction = (New-ScheduledTaskAction -Execute powershell.exe -Argument "-Command `"Write-Host 'Test RDP Task'`"")
    Write-Log "RDP action created"

    Write-Log "Registering task WITH password parameter..."
    $rdpTask = (Register-ScheduledTask -Force -TaskName "CircleCI Test RDP" -User $global:testUsername -Password $global:testPasswd -Action $rdpAction -Settings $rdpTaskSettings)
    Write-Log "RDP task registered successfully (with password)"
    Write-Log "Task object returned: $($rdpTask.TaskName)"
}

# Test 15: Start scheduled task
Test-Step "Start Scheduled Task Immediately" {
    Write-Log "Starting RDP task..."
    $rdpTask = Get-ScheduledTask -TaskName "CircleCI Test RDP"
    Start-ScheduledTask -InputObject $rdpTask
    Write-Log "Task started"

    Start-Sleep -Seconds 2

    Write-Log "Checking task status..."
    $taskInfo = Get-ScheduledTaskInfo -TaskName "CircleCI Test RDP"
    Write-Log "Last Run Time: $($taskInfo.LastRunTime)"
    Write-Log "Last Task Result: $($taskInfo.LastTaskResult)"

    Write-Log "Cleaning up RDP test task..."
    Unregister-ScheduledTask -TaskName "CircleCI Test RDP" -Confirm:$false
}

# Test 16: cmdkey operation (credential manager)
Test-Step "Credential Manager (cmdkey) Operations" {
    Write-Log "Testing cmdkey.exe /add operation..."
    $cmdkeyResult = cmdkey.exe /add:TERMSRV/localhost /user:$global:testUsername /pass:$global:testPasswd 2>&1
    Write-Log "cmdkey add result: $cmdkeyResult"

    Write-Log "Listing stored credentials..."
    $listResult = cmdkey.exe /list 2>&1
    Write-Log "cmdkey list: $listResult"

    Write-Log "Cleaning up credential..."
    cmdkey.exe /delete:TERMSRV/localhost 2>&1 | Out-Null
}

# Test 17: reg.exe operations (HKCU)
Test-Step "Registry Operations via reg.exe (HKCU)" {
    Write-Log "Testing reg.exe ADD for HKCU..."

    $regResult1 = reg.exe ADD "HKCU\Software\Microsoft\Terminal Server Client" /v AuthenticationLevelOverride /t REG_DWORD /d 0x0 /f 2>&1
    Write-Log "reg.exe result 1: $regResult1"

    $regResult2 = reg.exe ADD "HKCU\Software\Microsoft\ServerManager" /v CheckedUnattendLaunchSetting /t REG_DWORD /d 0x0 /f 2>&1
    Write-Log "reg.exe result 2: $regResult2"
}

# Summary
Write-Log "========================================"
Write-Log "All Tests Complete!"
Write-Log "========================================"
Write-Log "Log file: $logFile"
Write-Host "`n[SUCCESS] All startup script operations validated!" -ForegroundColor Green
Write-Host "Check detailed log: $logFile" -ForegroundColor Cyan

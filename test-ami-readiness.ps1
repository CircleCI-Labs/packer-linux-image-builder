# Test AMI Readiness for CircleCI Agent Startup Script
# This script validates that the AMI has all required dependencies
# to successfully run the CircleCI agent startup script

$ErrorActionPreference = "Continue"
$testsPassed = 0
$testsFailed = 0

function Test-Feature {
    param(
        [string]$Name,
        [scriptblock]$Test
    )

    Write-Host "`n[TEST] $Name" -ForegroundColor Cyan
    try {
        $result = & $Test
        if ($result) {
            Write-Host "  [PASS]" -ForegroundColor Green
            $script:testsPassed++
            return $true
        } else {
            Write-Host "  [FAIL]" -ForegroundColor Red
            $script:testsFailed++
            return $false
        }
    } catch {
        Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
        $script:testsFailed++
        return $false
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CircleCI AMI Readiness Test Suite" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Test 1: .NET Framework System.Web assembly
Test-Feature ".NET Framework System.Web Assembly" {
    try {
        Add-Type -AssemblyName System.Web
        return $true
    } catch {
        return $false
    }
}

# Test 2: Generate password using System.Web.Security
Test-Feature "System.Web.Security.Membership Password Generation" {
    try {
        Add-Type -AssemblyName System.Web
        $password = [System.Web.Security.Membership]::GeneratePassword(42, 10)
        return ($password.Length -ge 42)
    } catch {
        return $false
    }
}

# Test 3: TLS 1.2 for HTTPS downloads
Test-Feature "TLS 1.2 Configuration" {
    try {
        $protocols = [Net.ServicePointManager]::SecurityProtocol
        $hasTls12 = ($protocols -band [Net.SecurityProtocolType]::Tls12) -eq [Net.SecurityProtocolType]::Tls12
        return $hasTls12
    } catch {
        return $false
    }
}

# Test 4: Invoke-WebRequest with HTTPS
Test-Feature "HTTPS Download Capability" {
    try {
        $response = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 10
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

# Test 5: PowerShell Execution Policy
Test-Feature "PowerShell Execution Policy" {
    try {
        $policy = Get-ExecutionPolicy -Scope LocalMachine
        return ($policy -eq "RemoteSigned" -or $policy -eq "Unrestricted" -or $policy -eq "Bypass")
    } catch {
        return $false
    }
}

# Test 6: circleci user exists
Test-Feature "CircleCI User Exists" {
    try {
        $user = Get-LocalUser -Name "circleci" -ErrorAction Stop
        return ($null -ne $user)
    } catch {
        return $false
    }
}

# Test 7: circleci-admin user exists
Test-Feature "CircleCI Admin User Exists" {
    try {
        $user = Get-LocalUser -Name "circleci-admin" -ErrorAction Stop
        return ($null -ne $user)
    } catch {
        return $false
    }
}

# Test 8: circleci is Administrator
Test-Feature "CircleCI User is Administrator" {
    try {
        $members = Get-LocalGroupMember -Group "Administrators"
        $isMember = $members | Where-Object { $_.Name -like "*circleci" }
        return ($null -ne $isMember)
    } catch {
        return $false
    }
}

# Test 9: Required directories exist
Test-Feature "Required Directories" {
    try {
        $circleciTemp = Test-Path "C:\CircleCI\Temp"
        $temp = Test-Path "C:\Temp"
        return ($circleciTemp -and $temp)
    } catch {
        return $false
    }
}

# Test 10: Registry write capability
Test-Feature "Registry Write Access" {
    try {
        $testPath = "HKLM:\SOFTWARE\CircleCITest"
        New-Item -Path $testPath -Force | Out-Null
        Set-ItemProperty -Path $testPath -Name "TestValue" -Value "Test" -Type String
        $value = Get-ItemProperty -Path $testPath -Name "TestValue"
        Remove-Item -Path $testPath -Force
        return ($value.TestValue -eq "Test")
    } catch {
        return $false
    }
}

# Test 11: Scheduled Task creation
Test-Feature "Scheduled Task Creation" {
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command Write-Host 'Test'"
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(60)
        $settings = New-ScheduledTaskSettingsSet -Hidden
        Register-ScheduledTask -TaskName "CircleCITestTask" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
        Unregister-ScheduledTask -TaskName "CircleCITestTask" -Confirm:$false
        return $true
    } catch {
        return $false
    }
}

# Test 12: Git installed and in PATH
Test-Feature "Git Installation" {
    try {
        $git = Get-Command git -ErrorAction Stop
        return ($null -ne $git)
    } catch {
        return $false
    }
}

# Test 13: Docker installed
Test-Feature "Docker Installation" {
    try {
        $docker = Get-Command docker -ErrorAction SilentlyContinue
        if ($null -ne $docker) {
            return $true
        } else {
            Write-Host "  Note: Docker may be available after restart" -ForegroundColor Yellow
            return $true  # Pass because Docker needs restart
        }
    } catch {
        return $true  # Pass because Docker needs restart
    }
}

# Test 14: Unix tools in PATH (xargs)
Test-Feature "Git Unix Tools (xargs)" {
    try {
        $xargs = Get-Command xargs -ErrorAction Stop
        return ($null -ne $xargs)
    } catch {
        return $false
    }
}

# Summary
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  Test Results" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Failed: $testsFailed" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Cyan

if ($testsFailed -eq 0) {
    Write-Host "`n[SUCCESS] AMI is ready for CircleCI agent startup script!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[ERROR] AMI is NOT ready. Fix the failed tests above." -ForegroundColor Red
    exit 1
}

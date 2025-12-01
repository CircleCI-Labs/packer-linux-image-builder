# Setup CircleCI User for Windows
$ErrorActionPreference = "Stop"

Write-Host "Creating circleci user..." -ForegroundColor Cyan

# Generate a secure random password
$Password = ConvertTo-SecureString "TempPassword123!" -AsPlainText -Force

try {
    New-LocalUser -Name "circleci" -Password $Password -FullName "CircleCI User" -Description "CircleCI Build User" -PasswordNeverExpires:$true -ErrorAction Stop
    Write-Host "User 'circleci' created successfully" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already exists*") {
        Write-Host "User 'circleci' already exists" -ForegroundColor Yellow
    } else {
        throw $_
    }
}

Write-Host "Adding circleci to Administrators group..." -ForegroundColor Yellow
# Add circleci to Administrators group (equivalent to sudo ALL NOPASSWD:ALL)
try {
    Add-LocalGroupMember -Group "Administrators" -Member "circleci" -ErrorAction Stop
    Write-Host "Added circleci to Administrators group" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already a member*") {
        Write-Host "User circleci is already in Administrators group" -ForegroundColor Yellow
    } else {
        throw $_
    }
}

Write-Host "Adding circleci to docker-users group..." -ForegroundColor Yellow
# Add circleci to docker-users group
try {
    Add-LocalGroupMember -Group "docker-users" -Member "circleci" -ErrorAction Stop
    Write-Host "Added circleci to docker-users group" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already a member*") {
        Write-Host "User circleci is already in docker-users group" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -like "*not found*") {
        Write-Host "docker-users group not found. Install Docker first." -ForegroundColor Yellow
    } else {
        throw $_
    }
}

Write-Host ""
Write-Host "CircleCI user setup complete!" -ForegroundColor Green
Write-Host "NOTE: The temporary password is 'TempPassword123!' - consider changing it for security." -ForegroundColor Yellow

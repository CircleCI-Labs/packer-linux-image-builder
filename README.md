# Packer Template for Windows Server 2022 with Docker CE

A streamlined Packer template that builds a Windows Server 2022 AMI with Docker CE for CircleCI builds.

## What's Included

**Software:**
- .NET Framework 4.8 (includes System.Web assembly)
- Git 2.46.2
- Git-LFS 3.5.1
- Docker CE 27.3.1 (manually installed for reliability)
- docker-compose
- 7zip 24.8.0
- gzip 1.3.12
- Sysinternals 2024.7.23
- OpenSSH Server (configured for key-based auth only)

**System Configuration:**
- Windows Firewall disabled (all profiles)
- TLS 1.2 enabled for secure downloads
- PowerShell execution policy: RemoteSigned
- Git Unix tools in PATH (xargs, grep, etc.)

**Users:**
- `circleci` (Administrator)
- `circleci-admin` (Administrator)

**Directories:**
- `C:\CircleCI\Temp`
- `C:\Temp`

## Usage

```bash
# Initialize Packer
packer init windows-docker.pkr.hcl

# Validate configuration
packer validate windows-docker.pkr.hcl

# Build AMI
packer build windows-docker.pkr.hcl
```

## Files

- `windows-docker.pkr.hcl` - Main Packer configuration
- `setup-windows-ami.ps1` - Installs all required software (Docker CE, Git, tools) and creates users
- `install-ssh.ps1` - Configures OpenSSH Server
- `test-ami-readiness.ps1` - Validates AMI readiness (runs during build, also copied to C:\)
- `test-startup-script.ps1` - Debug tool for troubleshooting startup script failures (copied to C:\)
- `windows-userdata.txt` - WinRM setup for Packer
- `plugins.pkr.hcl` - Packer plugin requirements

## Testing

### During Build

The build includes comprehensive automated testing in two phases:

**1. `test-ami-readiness.ps1`** - Validates 15 dependencies:
- .NET Framework System.Web assembly
- TLS 1.2 configuration
- PowerShell execution policy
- Windows Firewall disabled
- User accounts and permissions
- Required directories
- Git and Unix tools
- Registry and scheduled task capabilities

**2. `test-startup-script.ps1`** - Simulates your actual user-data script:
- System.Web password generation
- User password changes
- Registry operations (UAC, CredentialsDelegation)
- Group Policy updates
- HTTPS downloads from S3
- Scheduled task creation
- Credential Manager operations

**Phase 1: Pre-Restart Tests**
- Tests run immediately after software installation
- Validates basic dependencies are installed correctly
- Catches configuration issues early

**Phase 2: Post-Restart Tests (Production State)**
- System restarts to enable Docker and apply all system changes
- Both tests re-run to validate the production state
- Verifies Docker, TLS 1.2, and all services work after restart
- Ensures the AMI matches the environment your user-data script will run in

**If any test fails in either phase, the AMI build fails** - ensuring the AMI is fully working before creation.

During build, you'll see real-time output and logs are saved to `C:\CircleCI\startup-test.log`.

**Build time:** ~25-30 minutes (includes thorough pre/post-restart testing)

### Debug Startup Script Issues

If your user-data startup script is failing, use `test-startup-script.ps1` to debug:

1. Launch an instance from the AMI
2. Connect via RDP
3. Run the test script:
```powershell
C:\test-startup-script.ps1
```

This will:
- Simulate all operations from the CircleCI agent startup script
- Log detailed output to `C:\CircleCI\startup-test.log`
- Show exactly which step is failing and why

Check the log file:
```powershell
Get-Content C:\CircleCI\startup-test.log
```

## Configuration

Variables can be overridden:
```bash
packer build -var="region=us-west-2" -var="windows_version=2019" windows-docker.pkr.hcl
```

---

### Disclaimer

CircleCI Labs, including this repo, is a collection of solutions developed by members of CircleCI's Field Engineering teams through our engagement with various customer needs.

✅ Created by engineers @ CircleCI
✅ Used by real CircleCI customers
❌ Not officially supported by CircleCI support

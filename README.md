# Packer Template for Windows Server 2022 with Docker CE

A streamlined Packer template that builds a Windows Server 2022 AMI with Docker CE for CircleCI builds.

## What's Included

**Software (versions from `windows2022/software.yml`):**
- .NET Framework 4.8 (includes System.Web assembly)
- Git 2.46.2
- Git-LFS 3.5.1
- Docker CE (Community Edition)
- docker-compose
- 7zip 24.8.0
- gzip 1.3.12
- Sysinternals 2024.7.23
- OpenSSH Server (configured for key-based auth only)

**System Configuration:**
- TLS 1.2 enabled for secure downloads
- PowerShell execution policy: RemoteSigned
- Git Unix tools in PATH (xargs, grep, etc.)

**Users:**
- `circleci` (Administrator)
- `circleci-admin` (Administrator)
- Password: `gFo8.UbL-@Ln*q-m` (change for production)

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
- `windows-userdata.txt` - WinRM setup for Packer
- `plugins.pkr.hcl` - Packer plugin requirements

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

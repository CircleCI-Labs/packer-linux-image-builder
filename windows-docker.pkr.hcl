# Common variables
variable "region" {
  default = "us-east-1"
  type    = string
}

variable "volume_type" {
  default = "gp3"
  type    = string
}

# Windows specific variables
variable "windows_instance_type" {
  default = "t3.medium"
  type    = string
}

variable "windows_ami_name" {
  default = "windows-docker-cci-server-{{timestamp}}"
  type    = string
}

variable "windows_ami_owner" {
  default = "801119661308"  # Amazon
  type    = string
}

variable "windows_volume_size" {
  default = 160
  type    = number
}

variable "windows_version" {
  default = "2022"
  type    = string
  description = "Windows Server version (2019 or 2022)"
}

source "amazon-ebs" "windows" {
  region        = var.region
  instance_type = var.windows_instance_type
  ami_name      = var.windows_ami_name

  source_ami_filter {
    filters = {
      name                = "Windows_Server-${var.windows_version}-English-Full-Base-*"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = [var.windows_ami_owner]
    most_recent = true
  }

  # WinRM configuration for Windows
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_use_ssl  = true
  winrm_insecure = true

  # User data to enable WinRM
  user_data_file = "windows-userdata.txt"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.windows_volume_size
    volume_type           = var.volume_type
    delete_on_termination = true
  }
}

build {
  sources = ["source.amazon-ebs.windows"]

  # Wait for Windows to be ready
  provisioner "powershell" {
    inline = [
      "Write-Host 'Waiting for Windows to be ready...'",
      "Start-Sleep -Seconds 30"
    ]
  }

  # Run setup-windows-ami.ps1
  provisioner "powershell" {
    script = "setup-windows-ami.ps1"
  }

  # Install and configure SSH
  provisioner "powershell" {
    script = "install-ssh.ps1"
  }

  # Test AMI readiness for CircleCI agent
  provisioner "powershell" {
    script = "test-ami-readiness.ps1"
  }

  # Test startup script operations (critical - mimics actual user-data script)
  provisioner "powershell" {
    script = "test-startup-script.ps1"
  }

  # Copy debug scripts to instance for troubleshooting
  provisioner "file" {
    sources = [
      "test-ami-readiness.ps1",
      "test-startup-script.ps1"
    ]
    destination = "C:\\"
  }

  # Optional: Restart and verify Docker (adds ~5 minutes to build time)
  # Uncomment the sections below if you want to verify Docker works during AMI creation
  # Docker will be fully functional when instances launch from this AMI regardless

  # provisioner "windows-restart" {
  #   restart_check_command = "powershell -command \"& {Write-Output 'restarted.'}\""
  # }

  # provisioner "powershell" {
  #   inline = [
  #     "Write-Host 'Waiting for Docker services to initialize...'",
  #     "Start-Sleep -Seconds 60"
  #   ]
  # }

  # provisioner "powershell" {
  #   inline = [
  #     "Write-Host 'Verifying Docker installation...'",
  #     "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
  #     "docker --version",
  #     "docker-compose --version",
  #     "git --version",
  #     "Write-Host 'All installations verified successfully!' -ForegroundColor Green"
  #   ]
  # }
}

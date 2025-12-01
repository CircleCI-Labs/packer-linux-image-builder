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
  default = 50
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

  # Run setup-docker.ps1
  provisioner "powershell" {
    script = "setup-docker.ps1"
  }

  # Optional: Run Windows Updates and restart if needed
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"& {Write-Output 'restarted.'}\""
  }

  # Verify installation
  provisioner "powershell" {
    inline = [
      "Write-Host 'Verifying Docker installation...'",
      "docker --version",
      "docker-compose --version",
      "git --version"
    ]
  }
}

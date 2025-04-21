variable "region" {
  default = "us-east-1"
}

source "amazon-ebs" "ubuntu" {
  region                  = var.region
  instance_type           = "t3.micro"
  ami_name                = "ubuntu-docker-cci-server-{{timestamp}}"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"]
    most_recent = true
  }
  ssh_username = "ubuntu"
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 30
    volume_type           = "gp2"
    delete_on_termination = true
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]
  
  provisioner "shell" {
    script = "setup-docker.sh"
    execute_command = "sudo -E bash '{{ .Path }}'"
  }
}

variable "region" {
  default = "us-east-1"
}

source "amazon-ebs" "al2" {
  region                  = var.region
  instance_type           = "t3.micro"
  ami_name                = "al2-docker-{{timestamp}}"
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["137112412989"] # Amazon
    most_recent = true
  }
  ssh_username            = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.al2"]

  provisioner "shell" {
    inline = [
      # Update and install packages
      "sudo yum update -y",
      "sudo amazon-linux-extras enable docker",
      "sudo yum install -y docker xfsprogs git",

      # Stop Docker before modifying storage
      "sudo systemctl stop docker",

      # Create a 20GB image file
      "sudo fallocate -l 20G /docker.img",
      "sudo mkfs.xfs -n ftype=1 /docker.img",

      # Create mount point
      "sudo mkdir -p /var/lib/docker",

      # Backup original Docker dir if needed
      "sudo mv /var/lib/docker /var/lib/docker.bak",
      "sudo mkdir -p /var/lib/docker",

      # Mount with pquota
      "echo '/docker.img /var/lib/docker xfs defaults,pquota 0 0' | sudo tee -a /etc/fstab",
      "sudo mount -a",

      # Docker daemon config to use --storage-opt
      "sudo mkdir -p /etc/docker",
      "echo '{\"storage-driver\": \"overlay2\", \"storage-opts\": [\"size=10G\"]}' | sudo tee /etc/docker/daemon.json",

      # Restore any original contents (optional)
      "sudo cp -a /var/lib/docker.bak/* /var/lib/docker/ || true",
      "sudo rm -rf /var/lib/docker.bak",

      # Enable and start Docker
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ec2-user",

      # Install Docker Compose
      "sudo curl -L \"https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "docker-compose version",

      # Setup CircleCI User
      "sudo useradd -m -s /bin/bash circleci",
      "echo 'circleci ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-circleci",
      "sudo usermod -aG docker circleci",

      # Confirm git installation
      "git --version"
    ]
  }
}
}

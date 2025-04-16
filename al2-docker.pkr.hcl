variable "region" {
  default = "us-east-1"
}

source "amazon-ebs" "al2" {
  region                  = var.region
  instance_type           = "t3.micro"
  ami_name                = "al2-docker-xfs-{{timestamp}}"

  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["137112412989"]
    most_recent = true
  }

  ssh_username = "ec2-user"

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 30
    volume_type           = "gp2"
    delete_on_termination = true
  }
}

provisioner "shell" {
  inline = [
    # Update and install packages
    "sudo yum update -y",
    "sudo amazon-linux-extras enable docker",
    "sudo yum install -y docker xfsprogs git",
    
    # Stop Docker before configuring storage
    "sudo systemctl stop docker || true",
    
    # Force unmount if already mounted
    "sudo umount /var/lib/docker || true",
    
    # Create XFS volume without quota options
    "sudo fallocate -l 20G /docker.img",
    "sudo mkfs.xfs -n ftype=1 /docker.img",
    "sudo mkdir -p /var/lib/docker",
    
    # Mount without quota options
    "sudo mount /docker.img /var/lib/docker",
    
    # Remove any existing fstab entry
    "sudo sed -i '/\\/docker.img/d' /etc/fstab",
    "echo '/docker.img /var/lib/docker xfs defaults 0 0' | sudo tee -a /etc/fstab",
    
    # Configure Docker without storage options
    "sudo mkdir -p /etc/docker",
    "echo '{\"storage-driver\": \"overlay2\"}' | sudo tee /etc/docker/daemon.json",
    
    # Start Docker
    "sudo systemctl daemon-reload",
    "sudo systemctl enable docker",
    "sudo systemctl start docker",
    
    # Verify Docker is running using sudo
    "sudo systemctl status docker",
    
    # Add ec2-user to docker group
    "sudo usermod -aG docker ec2-user",
    
    # Run Docker commands with sudo to avoid permission errors during build
    "sudo docker --version",
    "sudo docker info",
    
    # Install Docker Compose
    "sudo curl -L \"https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
    "sudo chmod +x /usr/local/bin/docker-compose",
    
    # Create circleci user
    "sudo useradd -m -s /bin/bash circleci",
    "echo 'circleci ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-circleci",
    "sudo usermod -aG docker circleci",
    
    # Verify docker-compose and git
    "docker-compose --version || sudo docker-compose --version",
    "git --version"
  ]
}
}

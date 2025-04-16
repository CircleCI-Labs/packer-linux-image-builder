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

build {
  sources = ["source.amazon-ebs.al2"]

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
    
    # Create XFS volume with explicit pquota option
    "sudo fallocate -l 20G /docker.img",
    "sudo mkfs.xfs -n ftype=1 /docker.img",
    "sudo mkdir -p /var/lib/docker",
    
    # Remove any existing fstab entry
    "sudo sed -i '/\\/docker.img/d' /etc/fstab",
    
    # Add new fstab entry with explicit pquota
    "echo '/docker.img /var/lib/docker xfs defaults,pquota 0 0' | sudo tee -a /etc/fstab",
    
    # Mount directly with explicit options instead of using fstab
    "sudo mount -o pquota /docker.img /var/lib/docker",
    
    # Verify the mount has pquota (not prjquota)
    "echo 'Verifying mount options:'",
    "mount | grep docker",
    
    # Docker config with overlay2 and size option
    "sudo mkdir -p /etc/docker",
    "echo '{\"storage-driver\": \"overlay2\", \"storage-opts\": [\"size=10G\"]}' | sudo tee /etc/docker/daemon.json",
    
    # Restart Docker properly
    "sudo systemctl daemon-reload",
    "sudo systemctl enable docker",
    "sudo systemctl start docker || (echo 'Docker failed to start' && sudo systemctl status docker && exit 1)",
    
    # Add ec2-user to docker group
    "sudo usermod -aG docker ec2-user",
    
    # Install Docker Compose
    "sudo curl -L \"https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
    "sudo chmod +x /usr/local/bin/docker-compose",
    
    # Create circleci user
    "sudo useradd -m -s /bin/bash circleci",
    "echo 'circleci ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-circleci",
    "sudo usermod -aG docker circleci",
    
    # Verify everything works
    "docker info | grep 'Storage Driver'",
    "docker --version",
    "docker-compose version",
    "git --version"
  ]
}
}

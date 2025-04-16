#!/bin/bash
set -e

echo "Updating system packages..."
sudo yum update -y
sudo amazon-linux-extras enable docker
sudo yum install -y docker xfsprogs git

echo "Stopping Docker service if running..."
sudo systemctl stop docker || true

echo "Unmounting Docker volume if mounted..."
sudo umount /var/lib/docker || true

echo "Creating XFS volume for Docker..."
sudo fallocate -l 20G /docker.img
sudo mkfs.xfs -n ftype=1 /docker.img
sudo mkdir -p /var/lib/docker

echo "Mounting Docker volume with pquota option..."
# The key change is here - explicitly using pquota mount option
sudo mount -o pquota /docker.img /var/lib/docker

echo "Verifying mount options:"
mount | grep docker

echo "Updating fstab with pquota option..."
sudo sed -i '/\/docker.img/d' /etc/fstab
# Also adding pquota to fstab entry
echo '/docker.img /var/lib/docker xfs defaults,pquota 0 0' | sudo tee -a /etc/fstab

echo "Configuring Docker with storage options..."
sudo mkdir -p /etc/docker
# Adding the storage-opts that you need
echo '{
  "storage-driver": "overlay2",
  "storage-opts": ["size=10G"]
}' | sudo tee /etc/docker/daemon.json

echo "Starting Docker service..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker || {
  echo "Docker failed to start. Checking status:"
  sudo systemctl status docker
  
  # Fall back to basic config if storage-opt fails
  echo "Trying again without storage options..."
  echo '{"storage-driver": "overlay2"}' | sudo tee /etc/docker/daemon.json
  sudo systemctl restart docker
}

echo "Verifying Docker service..."
sudo systemctl status docker

echo "Adding ec2-user to docker group..."
sudo usermod -aG docker ec2-user

echo "Checking Docker version and info..."
sudo docker --version
sudo docker info

echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create a symlink to ensure docker-compose is in the PATH
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "Creating circleci user..."
sudo useradd -m -s /bin/bash circleci
echo 'circleci ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-circleci
sudo usermod -aG docker circleci

echo "Verifying installations..."
# Explicitly check docker-compose in the full path
echo "Docker Compose version:"
/usr/local/bin/docker-compose --version
echo "Git version:"
git --version

# Test container size limits if Docker started with storage options
if sudo docker info | grep -q "size=10G"; then
  echo "Container size limits are working!"
  echo "Testing with a container:"
  sudo docker run --rm alpine df -h
else
  echo "NOTE: Container size limits are not enabled."
  echo "To enable size limits, you may need to remount /var/lib/docker with pquota and restart Docker."
fi

echo "Setup complete!"

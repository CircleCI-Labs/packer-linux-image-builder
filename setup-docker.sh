#!/bin/bash
set -e

echo "Updating system packages..."
sudo yum update -y
sudo amazon-linux-extras enable docker
sudo yum install -y docker xfsprogs git lvm2

echo "Stopping Docker service if running..."
sudo systemctl stop docker || true

echo "Unmounting Docker volume if mounted..."
sudo umount /var/lib/docker || true

echo "Creating Docker storage with devicemapper..."
# Create a data file for Docker
sudo fallocate -l 20G /docker-data.img
sudo fallocate -l 2G /docker-metadata.img

# Set up loop devices
sudo losetup -fP /docker-data.img
sudo losetup -fP /docker-metadata.img

# Get the loop device names
DATA_DEV=$(losetup -a | grep docker-data | awk -F: '{print $1}')
META_DEV=$(losetup -a | grep docker-metadata | awk -F: '{print $1}')

echo "Using $DATA_DEV for data and $META_DEV for metadata"

# Configure Docker to use devicemapper
sudo mkdir -p /etc/docker
cat << EOF | sudo tee /etc/docker/daemon.json
{
  "storage-driver": "devicemapper",
  "storage-opts": [
    "dm.directlvm_device=$DATA_DEV",
    "dm.directlvm_device_force=true",
    "dm.thinp_percent=95",
    "dm.thinp_metapercent=1",
    "dm.thinp_autoextend_threshold=80",
    "dm.thinp_autoextend_percent=20",
    "dm.directlvm_device_force=true",
    "dm.basesize=10G"
  ]
}
EOF

echo "Starting Docker service..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker || {
  echo "Docker failed to start with devicemapper config."
  sudo systemctl status docker
  
  echo "Trying simplified devicemapper config..."
  cat << EOF | sudo tee /etc/docker/daemon.json
{
  "storage-driver": "devicemapper",
  "storage-opts": [
    "dm.basesize=10G"
  ]
}
EOF
  sudo systemctl restart docker || {
    echo "Docker still failed to start. Falling back to overlay2..."
    echo '{"storage-driver": "overlay2"}' | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker
  }
}

echo "Verifying Docker service..."
sudo systemctl status docker

echo "Adding ec2-user to docker group..."
sudo usermod -aG docker ec2-user

echo "Checking Docker version and info..."
sudo docker --version
sudo docker info | grep -A 10 "Storage Driver"

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
echo "Docker Compose version:"
/usr/local/bin/docker-compose --version
echo "Git version:"
git --version

# Create a startup script that ensures Docker has the right config
cat << 'EOF' | sudo tee /etc/rc.local
#!/bin/bash
# Ensure Docker has the right storage configuration at boot
# This handles cases where the Docker service starts before loop devices are available

if grep -q devicemapper /etc/docker/daemon.json; then
  # Wait a moment for devices to be available
  sleep 2
  
  # Restart Docker to ensure it has the right config
  systemctl restart docker
fi
EOF

sudo chmod +x /etc/rc.local

echo "Setup complete!"

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

echo "Creating XFS volume for Docker..."
sudo fallocate -l 20G /docker.img
sudo mkfs.xfs -n ftype=1 /docker.img
sudo mkdir -p /var/lib/docker

echo "Mounting Docker volume..."
# Just use standard mount, let Amazon Linux handle it
sudo mount /docker.img /var/lib/docker

echo "Verifying mount options:"
mount | grep docker

echo "Updating fstab..."
sudo sed -i '/\/docker.img/d' /etc/fstab
echo '/docker.img /var/lib/docker xfs defaults 0 0' | sudo tee -a /etc/fstab

echo "Configuring Docker..."
sudo mkdir -p /etc/docker

# Use a simple config that should work in all cases
echo '{"storage-driver": "overlay2"}' | sudo tee /etc/docker/daemon.json

echo "Starting Docker service..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker

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
echo "Docker Compose version:"
sudo /usr/local/bin/docker-compose --version
echo "Git version:"
git --version

# Create a script to set up Docker size limits after boot
cat << 'EOF' | sudo tee /usr/local/bin/configure-docker-size-limits.sh
#!/bin/bash

# Wait for Docker to start
until systemctl is-active docker > /dev/null; do
  sleep 1
done

# Get current mount options
MOUNT_OPTS=$(mount | grep /var/lib/docker | grep -o '(.*)')

if echo "$MOUNT_OPTS" | grep -q "prjquota"; then
  # Try to configure devicemapper with size limits
  cat > /tmp/daemon.json << INNER_EOF
{
  "storage-driver": "devicemapper",
  "storage-opts": [
    "dm.basesize=10G"
  ]
}
INNER_EOF

  # Backup current config
  cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
  
  # Apply new config
  cp /tmp/daemon.json /etc/docker/daemon.json
  
  # Restart Docker
  systemctl restart docker
  
  # Check if it worked
  if ! systemctl is-active docker > /dev/null; then
    # Restore original config
    cp /etc/docker/daemon.json.bak /etc/docker/daemon.json
    systemctl restart docker
    echo "Could not enable size limits, reverting to standard config"
  else
    echo "Docker configured with size limits"
  fi
fi
EOF

sudo chmod +x /usr/local/bin/configure-docker-size-limits.sh

# Create systemd service to run this script at startup
cat << 'EOF' | sudo tee /etc/systemd/system/docker-size-limits.service
[Unit]
Description=Docker Size Limits Configuration
After=docker.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/configure-docker-size-limits.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl enable docker-size-limits.service

echo "Setup complete!"

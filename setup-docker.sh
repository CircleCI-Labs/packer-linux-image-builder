#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
UNAME="$(uname -r)"
export UNAME

echo "-------------------------------------------"
echo "     Performing System Updates"
echo "-------------------------------------------"
sudo apt-get update && apt-get -y upgrade

echo "--------------------------------------"
echo "        Installing NTP and Git"
echo "--------------------------------------"
sudo apt-get install -y ntp git

echo "--------------------------------------"
echo "        Installing Docker"
echo "--------------------------------------"
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get install -y "linux-image-$UNAME"
sudo apt-get update
sudo apt-get -y install docker-ce=5:25.0.2-1~ubuntu.20.04~focal \
                   docker-ce-cli=5:25.0.2-1~ubuntu.20.04~focal

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


echo "Setup complete!"

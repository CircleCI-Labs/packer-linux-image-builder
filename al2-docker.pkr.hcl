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
      "sudo yum update -y",
      "sudo amazon-linux-extras enable docker",
      "sudo yum install -y docker",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ec2-user",

      # Install docker-compose
      "sudo curl -L \"https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "docker-compose version"
    ]
  }
}

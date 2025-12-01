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

variable "default_keypair_name" {
  default = "terraform_ec2_key"
}

variable "monitor_instance_type" {
  default = "t2.micro"
}

variable "monitor_servers" {
  default = "1"
}

variable "owner" {
  default = "Monitoring"
}


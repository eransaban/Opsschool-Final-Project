#Monitoring Security Group
resource "aws_security_group" "monitor_sg" {
  name        = "monitor_sg_1"
  description = "Security group for monitoring server"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all SSH External
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow all traffic to HTTP port 3000
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow all traffic to HTTP port 9090
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/16"]
  }
}


# Allocate the EC2 monitoring instance
resource "aws_instance" "monitor" {
  count         = var.monitor_servers
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.monitor_instance_type
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name


  subnet_id     = element(tolist(data.aws_subnet_ids.private_sub_ids.ids), count.index)
  vpc_security_group_ids = [aws_security_group.monitor_sg.id]
  key_name               = var.default_keypair_name

  tags = {
    Owner = var.owner
    Name  = "Monitor-${count.index}"
  }

  user_data = file("Scripts/mon_usrdata.sh")

}


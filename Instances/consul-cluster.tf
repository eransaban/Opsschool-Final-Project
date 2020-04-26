##################################################################################
# DATA
##################################################################################

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_instance" "consul-server" {
  count = 3
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name = "terraform_ec2_key"
  vpc_security_group_ids = [aws_security_group.consul_sg.id]
  
  #element with count index, pull one stirng from the list with rotation over,  tolist change object to list cuz element can only work with lists
  subnet_id     = element(tolist(data.aws_subnet_ids.private_sub_ids.ids), count.index)
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  
  user_data = file("Scripts/consul-server.sh")

  tags = {
      consul_server = "true"
      Name = "Consul${count.index}"
  }
}

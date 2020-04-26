resource "aws_security_group" "bastion-sg" {
  name = "bastion security group"
  description = "Allow conntion to private subnets"
  vpc_id      = data.aws_vpc.selected.id

    egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #shuld be change to local ip address
    }

    ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #shuld be change to local ip address
    }

    ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #shuld be change to local ip address
    }
    
    ingress {
    from_port = 8888
    to_port = 8888
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #shuld be change to local ip address        
    }

    ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow Export Metrics"
  }
    
    ingress {
    from_port = 9090
    to_port = 9090
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #shuld be change to local ip address        
    }

    ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #shuld be change to local ip address        
    }
    
    ingress {
    from_port = 5601
    to_port = 5601
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #shuld be change to local ip address        
    }
  tags = {
  Name = "bastion security group"
  }
}

resource "aws_instance" "bastion" {
  ami = "ami-07d0cf3af28718ef8"
  instance_type = "t2.micro"
  key_name = "terraform_ec2_key"
  subnet_id = data.aws_subnet.public_subnet1.id
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name

  tags = {
    Name = "bastion"
  }
  vpc_security_group_ids = [aws_security_group.bastion-sg.id]
  user_data = file("Scripts/consul-agent-bastion.sh")

}

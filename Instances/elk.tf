resource "aws_security_group" "elk_sg" {
  name = "elk_sg"
  description = "Allow Elk inbound traffic"
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
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Logstash"
   }
  ingress {
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "ElasticSearch"
   }

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "ElasticSearch"
   }
  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Kibana"
  }
    ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Node Exporter"
  }

  tags = {
    Name = "elk_sg"
  }
}


resource "aws_instance" "elk" {
  ami = "ami-07d0cf3af28718ef8"
  instance_type = "t2.small"
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  key_name               = var.default_keypair_name
  subnet_id     = element(tolist(data.aws_subnet_ids.private_sub_ids.ids), 1)

  tags = {
    Name = "Elk Stack"
  }
  vpc_security_group_ids = [aws_security_group.elk_sg.id]
  user_data = file("Scripts/elk_userdata.sh")
  }


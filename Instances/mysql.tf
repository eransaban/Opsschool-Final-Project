variable "sqlpassword" {}
variable "sqluser" {}

resource "aws_security_group" "mysql_sg" {
  name = "mysql_sg"
  description = "Allow Mysql inbound traffic"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    security_groups = [data.aws_security_group.k8s_workers_sg.id]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
    
  
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow Export Metrics"
  }

  ingress {
    from_port   = 9104
    to_port     = 9104
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow Export Metrics"
  }
  
  tags = {
    Name = "mysql_sg"
  }
}

data "template_file" "mysql_userdata" {
  template = file("${path.module}/templates/mysql_usrdata.sh.tpl")

  vars = {
      VER = "0.12.1"
      sqluser = var.sqluser
      sqlpassword = var.sqlpassword
      CONSUL_VERSION = "1.6.2"
      PROMETHEUS_DIR = "/opt/prometheus"
      NODE_EXPORTER_VERSION = "0.18.1"
  }
}

data "template_cloudinit_config" "mysql" {
  part {
    content = data.template_file.mysql_userdata.rendered
  }
}


#Create Lunch Configuration

resource "aws_launch_configuration" "mysql_conf" {
  name_prefix   = "mysql-primary"
  image_id      = "ami-07d0cf3af28718ef8"
  instance_type = "t2.micro"
  key_name      = var.default_keypair_name
  user_data = data.template_cloudinit_config.mysql.rendered
  security_groups = [aws_security_group.mysql_sg.id]
  iam_instance_profile  = data.aws_iam_instance_profile.s3.name

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "mysql_scale" {
  #subnet_id = data.aws_subnet.private_subnet2.id
  vpc_zone_identifier       = ["${data.aws_subnet.private_subnet1.id}","${data.aws_subnet.private_subnet2.id}", "${data.aws_subnet.private_subnet3.id}"]
  name                 = "Mysql-asg"
  launch_configuration = aws_launch_configuration.mysql_conf.name
  min_size             = 1
  max_size             = 1

  lifecycle {
    create_before_destroy = true
  }
}

# resource "aws_instance" "mysql-primary" {
#   ami = "ami-07d0cf3af28718ef8"
#   instance_type = "t2.micro"
#   key_name               = var.default_keypair_name
#   subnet_id = data.aws_subnet.private_subnet2.id
#   iam_instance_profile  = data.aws_iam_instance_profile.s3.name

#   tags = {
#     Name = "Mysql Primary"
#   }
#   vpc_security_group_ids = [aws_security_group.mysql_sg.id]

#   user_data = data.template_cloudinit_config.mysql.rendered

#   }

  data "template_file" "mysql_bkp_userdata" {
  template = file("${path.module}/templates/mysql_usrdata_bkp.sh.tpl")

  vars = {
      VER = "0.12.1"
      sqluser = var.sqluser
      sqlpassword = var.sqlpassword
      CONSUL_VERSION = "1.6.2"
      PROMETHEUS_DIR = "/opt/prometheus"
      NODE_EXPORTER_VERSION = "0.18.1"
  }
}

data "template_cloudinit_config" "mysql_bkp" {
  part {
    content = data.template_file.mysql_bkp_userdata.rendered
  }
}

  resource "aws_instance" "mysql-bkp" {
  ami = "ami-07d0cf3af28718ef8"
  instance_type = "t2.micro"
  key_name               = var.default_keypair_name
  subnet_id = data.aws_subnet.private_subnet3.id
  iam_instance_profile  = data.aws_iam_instance_profile.s3.name

  tags = {
    Name = "Mysql Backup"
  }
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]

  user_data = data.template_cloudinit_config.mysql_bkp.rendered
  depends_on = [aws_autoscaling_group.mysql_scale]
  }
  
provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}
variable "NODE_NAME" {}
variable "USERID" {}
variable "PASSWORD" {}
variable "NODE_SLAVE_HOME" {}
variable "EXECUTORS" {}
variable "LABELS" {}

#Create a cute name for our slaves
resource "random_pet" "slave" {
}

resource "aws_security_group" "jenkins_slave-private" {
  name = "jenkins-slave-sg"
  vpc_id      = data.aws_vpc.selected.id
  description = "Allow Jenkins slave inbound traffic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 50000
    to_port = 50000
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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
  tags = {
    Name = "jenkins-slave-sg-private"
  }
}

resource "aws_instance" "jenkins_slave_private" {
  count = 1
  ami = "ami-07d0cf3af28718ef8"
  instance_type = "t2.micro"
  key_name = "terraform_ec2_key"
  subnet_id = data.aws_subnet.private_subnet1.id
  depends_on = [aws_instance.jenkins_master]
  iam_instance_profile  = data.aws_iam_role.jen_slave_role.id
  #for consule   iam_instance_profile   = "${aws_iam_instance_profile.consul-join.name}"

  tags = {
    Name = "Jenkins Slave Private ${count.index}"
  }
  vpc_security_group_ids = [aws_security_group.jenkins_slave-private.id]

  # connection {
  #   host = aws_instance.jenkins_slave[count.index].public_ip
  #   user = "ubuntu"
  #   private_key = file("jenkins_ec2_key")
  # }

  user_data = file("Scripts/consul-agent-jenkins-slave.sh")
  # user_data = <<EOT
  #         #! /bin/bash
  #         echo \\'StrictHostKeyChecking\\' no >> sudo tee -a /etc/ssh/ssh_config
  #         sudo apt-get update -y
  #         sudo apt install docker.io -y
  #         sudo systemctl start docker
  #         sudo systemctl enable docker
  #         sudo usermod -aG docker ubuntu
  #         mkdir -p /home/ubuntu/jenkinshome
  #         sudo chown -R ubuntu:ubuntu /home/ubuntu/jenkinshome
  #         sudo chmod 766 /var/run/docker.sock
  #         sudo docker run -d --privileged -e JENKINS_URL=http://${aws_instance.jenkins_master.public_ip}:8080 -e JENKINS_AUTH=${var.USERID}:${var.PASSWORD} -e JENKINS_SLAVE_NAME=${var.NODE_NAME}${random_pet.slave.id} -e JENKINS_SLAVE_NUM_EXECUTORS=${var.EXECUTORS} -e JENKINS_SLAVE_LABEL=${var.LABELS} -v /home/ubuntu/jenkinshome:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock eransaban/jenkins-slave-docker2
  # EOT
    

    provisioner "local-exec" {
    command = "echo ${var.sqluser} > ../secrets/k8suser.txt"
    on_failure = continue
  } 
      provisioner "local-exec" {
    command = "echo ${var.sqlpassword} > ../secrets/k8spass.txt"
    on_failure = continue
  } 

    provisioner "local-exec" {
    command = "echo ${aws_instance.jenkins_master.private_ip} ansible_ssh_extra_args=\\'-o StrictHostKeyChecking=no -o ProxyCommand=\\\"ssh -W %h:%p -q -o StrictHostKeyChecking=no -i jenkins_ec2_key ubuntu@${aws_instance.bastion.public_ip}\\\"\\' > masterip.yml"
  }  

    provisioner "local-exec" {
    command = "ansible-playbook -i masterip.yml master-wait-playbook.yml -u ubuntu -b --private-key=jenkins_ec2_key"
    on_failure = continue

  } 

    provisioner "local-exec" {
    command = "echo ${aws_instance.jenkins_slave_private[count.index].private_ip} ansible_ssh_extra_args=\\'-o StrictHostKeyChecking=no -o ProxyCommand=\\\"ssh -W %h:%p -q -o StrictHostKeyChecking=no -i jenkins_ec2_key ubuntu@${aws_instance.bastion.public_ip}\\\"\\' > slave_private_ip.yml"
    } 

    provisioner "local-exec" {
    command = "./helm_setup.sh"
    on_failure = continue
  }  
  # provisioner "local-exec" {
  # command = "sleep 120"
  # }  

    provisioner "local-exec" {
    command = "echo ${aws_instance.monitor[0].private_ip} ansible_ssh_extra_args=\\'-o StrictHostKeyChecking=no -o ProxyCommand=\\\"ssh -W %h:%p -q -o StrictHostKeyChecking=no -i jenkins_ec2_key ubuntu@${aws_instance.bastion.public_ip}\\\"\\' > monitor.yml"
  }

    provisioner "local-exec" {
    command = "ansible-playbook -i monitor.yml monitor-playbook.yml -u ubuntu -b --private-key=jenkins_ec2_key"
    on_failure = continue
  } 

    provisioner "local-exec" {
    command = "ansible-playbook -i slave_private_ip.yml slave-playbook.yml -u ubuntu -b --private-key=jenkins_ec2_key -e jenkinsurl=${aws_instance.jenkins_master.private_ip} -e slavename=${var.NODE_NAME}${random_pet.slave.id} -e executors=${var.EXECUTORS} -e labels=${var.LABELS}"
    on_failure = continue
  }  

    provisioner "local-exec" {
    command = "ansible-playbook -i masterip.yml master-playbook.yml -u ubuntu -b --private-key=jenkins_ec2_key"
    on_failure = continue
  } 
}

output "Bastion_ip" {
  value = aws_instance.bastion.public_ip
  description = "consul = 8888, jenkins 8080, grafana 3000, prometheus 9090 all with https://bastion:port"
}
output "mon_private_ip" {
  value = aws_instance.monitor.*.private_ip
}

output "consul_private_ip" {
  value = aws_instance.consul-server.*.private_ip
}

output "jenkins_ip" {
   value = aws_instance.jenkins_master.private_ip
}

output "jenkins_slave_ip" {
   value = aws_instance.jenkins_slave_private[0].private_ip
}

output "mysql_bkp_ip" {
  value = aws_instance.mysql-bkp.private_ip
}


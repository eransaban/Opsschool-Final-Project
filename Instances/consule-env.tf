# provider "aws" {
#   region = "us-east-1"
# }

resource "aws_security_group" "consul_sg" {
  name        = "consul-sg"
  description = "Allow ssh & consul inbound traffic"
  vpc_id = data.aws_vpc.selected.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all inside security group"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow ssh from the world"
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow consul UI access from the world"
  }
    #for agent conenction
    ingress {
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow consul agent access from the vpc"
  }
    #for agent connection
    ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow consul agent access from the vpc"
  }
    ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow Export Metrics"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    description     = "Allow all outside security group"
  }
}

# Create an IAM role for the auto-join
resource "aws_iam_role" "consul-join" {
  name               = "consul-join-role"
  assume_role_policy = file("${path.module}/templates/policies/assume-role.json")
}

# Create the policy
resource "aws_iam_policy" "consul-join" {
  name        = "consul-join-policy"
  description = "Allows Consul nodes to describe instances for joining."
  policy      = file("${path.module}/templates/policies/describe-instances.json")
}

# Attach the policy + add the policy to several roles
resource "aws_iam_policy_attachment" "consul-join" {
  name       = "consul-join-attachment"
  roles      = ["${aws_iam_role.consul-join.name}","${data.aws_iam_role.jen_slave_role.name}","${data.aws_iam_role.s3.name}"]
  policy_arn = aws_iam_policy.consul-join.arn
}

# Create the instance profile
resource "aws_iam_instance_profile" "consul-join" {
  name  = "consul-join-profile"
  role = aws_iam_role.consul-join.name
}

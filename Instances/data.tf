##################################################################################
# DATA
##################################################################################
terraform {
  required_version = ">= 0.12.0"
}

# provider "aws" {
#   version = ">= 2.28.1"
#   region  = var.region
# }

provider "random" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

data "aws_vpc" "selected" {
  default = false
  cidr_block = "10.0.0.0/16"
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.selected.id
}

data "aws_subnet_ids" "private_sub_ids" {
  vpc_id = data.aws_vpc.selected.id

  tags = {
    Name = "eks-vpc-test-private*"
  }
}

data "aws_subnet" "public_subnet1" {
  vpc_id = data.aws_vpc.selected.id
  cidr_block = "10.0.4.0/24"  
   }

data "aws_subnet" "public_subnet2" {
  vpc_id = data.aws_vpc.selected.id
  cidr_block = "10.0.5.0/24"  
   }

data "aws_subnet" "public_subnet3" {
  vpc_id = data.aws_vpc.selected.id
  cidr_block = "10.0.6.0/24"  
   }

data "aws_subnet" "private_subnet1" {
  vpc_id = data.aws_vpc.selected.id
  cidr_block = "10.0.1.0/24"  
   }

data "aws_subnet" "private_subnet2" {
  vpc_id = data.aws_vpc.selected.id
  cidr_block = "10.0.2.0/24"  
   }

data "aws_subnet" "private_subnet3" {
  vpc_id = data.aws_vpc.selected.id
  cidr_block = "10.0.3.0/24"  
   }

data "aws_iam_role" "jen_slave_role" {
  name = "EKS-jen-role"
}

data "aws_security_group" "k8s_workers_sg" {
    filter {
    name   = "group-name"
    values = ["worker_group_mgmt_one*"]
  }
}

data "aws_iam_role" "s3" {
  name = "s3_role"
}
data "aws_iam_instance_profile" "s3" {
  name = "s3_profile"
}

##################################################################################
# Remote Backend
##################################################################################
terraform {
  backend "s3" {
    bucket = "saban-tf-backend"
    key    = "infra-backend"
    region = "us-east-1"
  }
}
#!/bin/sh

cd s3
terraform init -input=false
terraform apply -input=false -auto-approve
cd ../vpc
terraform init -input=false
terraform apply -input=false -auto-approve
cd ../Instances
terraform init -input=false
terraform apply -input=false -auto-approve



#!/bin/sh
kubectl delete all --all

cd Instances
terraform destroy -input=false -auto-approve
cd ../vpc
terraform destroy -input=false -auto-approve
cd ../s3
terraform destroy -input=false -auto-approve



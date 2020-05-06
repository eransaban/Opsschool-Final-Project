# Opsschool-Final-Project
Final Project Ops School 2020

This project was written as part of ops school winter 2020 course project

the object is to automatically create a full aws vpc with EKS(k8s) and a ci\cd pipeline to pull a project off github and build a docker image and deploy it on eks with monitoring.

Prerequisites:

a linux host (this project assume all os's involved are ubuntu if you use other os please adjsut accordingly folder names and userdata)
on this host should be installed aws cli (and configured) terraform ansible kubectl aws-iam-authenticator

Jenkins docker machines (you could use mine or create your own from dockerfile attached)

Instructions:

create an empty IAM ec2 role and copy it's ARN it should be placed in 2 places in EKS variables tf and on jenkins slave resource creation
there are 3 parts in this project first part is creating 2 s3 buckets 
2nd part is the network environment VPC and EKS (a long process) 
3rd part is the rest of the nodes (Jenkins master & slave,elk,prom,grafana,mysql)

* sometime tf doesn't create the private certificate
so theres a script to create an empty file and also give execute permission to several scripts in the the project 
fix_cert.sh

you can run the project using script project.sh make sure to give it execute permissions
chmod +x projectrun.sh

AWS machine costs
some of the macine in this project are ec2.small 
and not ec2.micro (free tier)
because of lake of memory on the ec2.micro


*Grafana and dockers folders
there are files i used in this project and are available from another git or already made as a docker image
the folders are added for review 

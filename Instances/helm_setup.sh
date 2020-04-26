#!/usr/bin/env bash
set -e
#create Vars
dbuser=$(cat ../secrets/k8suser.txt)
dbkey=$(cat ../secrets/k8spass.txt)
#Copy out kubeconfig file to the default location
cp ../vpc/kubeconfig_eran-ops-eks-project ~/.kube/config -f
#Create consul Secret Gossip
kubectl create secret generic consul-gossip-encryption-key --from-literal=key=uDBV4e+LbFW3019YKPxIrg==
#create app db-username
kubectl create secret generic dbusername --from-literal=user=$dbuser
#create app db-password
kubectl create secret generic dbpassword --from-literal=password=$dbkey
#install consul helm chart with config.yaml overrights
helm install hashicorp helm/consul-helm -f helm/config.yaml
#save the dns ip to varible
dnsip=$(kubectl get svc hashicorp-consul-dns -o jsonpath='{.spec.clusterIP}')
#save the current dns configuration
kubectl get configmaps coredns -n kube-system -o yaml > helm/coredns.yaml
#add the consul dns part to the yaml
sed -i '/kind: ConfigMap/e cat helm/coreconsul.txt' helm/coredns.yaml
#add the dns varible we extracted to the right location 
sed -i '/22/s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/'$dnsip'/' helm/coredns.yaml
#update the core dns
kubectl apply -f helm/coredns.yaml
#Install Prometheus helm
helm install prom stable/prometheus -f promhelm/values.yaml

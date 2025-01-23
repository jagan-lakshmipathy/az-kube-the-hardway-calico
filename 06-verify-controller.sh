#!/bin/zsh

#####################################
#      Run this on your desktop
#####################################
  
KUBERNETES_PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes \
  -n kubernetes-pip --query ipAddress -otsv)

curl --cacert ca.pem https://$KUBERNETES_PUBLIC_IP_ADDRESS:6443/version
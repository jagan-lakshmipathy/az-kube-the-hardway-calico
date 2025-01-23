#!/bin/zsh

#####################################
#      Run this on your desktop
#####################################
  

az network lb probe create -g kubernetes \
  --lb-name kubernetes-lb \
  --name kubernetes-apiserver-probe \
  --port 6443 \
  --protocol tcp

echo "01-Created LB Probe."

az network lb rule create -g kubernetes \
  -n kubernetes-apiserver-rule \
  --protocol tcp \
  --lb-name kubernetes-lb \
  --frontend-ip-name LoadBalancerFrontEnd \
  --frontend-port 6443 \
  --backend-pool-name kubernetes-lb-pool \
  --backend-port 6443 \
  --probe-name kubernetes-apiserver-probe

echo "02-Created LB Rules for the probe."
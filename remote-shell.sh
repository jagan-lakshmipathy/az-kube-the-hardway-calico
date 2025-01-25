#!/bin/zsh

#===================================
#   SSH into each Controller
#===================================

CONTROLLER=$1

PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes \
  -n ${CONTROLLER}-pip --query "ipAddress" -otsv)

echo
ssh kuberoot@${PUBLIC_IP_ADDRESS}


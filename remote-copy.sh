#!/bin/zsh

#===================================
#   SSH into each Controller
#===================================

INSTAMCE=$1
FILE=$2

PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes \
  -n ${INSTAMCE}-pip --query "ipAddress" -otsv)


  scp -o StrictHostKeyChecking=no ${FILE} kuberoot@${PUBLIC_IP_ADDRESS}:~/
  echo "03-Copied ${FILE} to ${INSTAMCE}"


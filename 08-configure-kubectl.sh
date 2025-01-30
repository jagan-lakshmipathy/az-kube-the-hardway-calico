#!/bin/zsh

KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show -g kubernetes \
  -n kubernetes-pip --query ipAddress -otsv)

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kubernetes-the-hard-way.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --kubeconfig=kubernetes-the-hard-way.kubeconfig

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=kubernetes-the-hard-way.kubeconfig

kubectl config use-context kubernetes-the-hard-way --kubeconfig=kubernetes-the-hard-way.kubeconfig
ls -al kubernetes-the-hard-way*
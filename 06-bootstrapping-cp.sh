#!/bin/bash

PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes \
  -n ${CONTROLLER}-pip --query "ipAddress" -otsv)

ssh kuberoot@${PUBLIC_IP_ADDRESS}
#===================================
#   Install
#===================================
sudo mkdir -p /etc/kubernetes/config
echo "01-Created config directory /etc/kubernetes/config"
VERSION="1.29.12"
wget -q --show-progress --https-only --timestamping \
  https://dl.k8s.io/v$VERSION/kubernetes-client-linux-amd64.tar.gz \
  https://dl.k8s.io/v$VERSION/kubernetes-server-linux-amd64.tar.gz \
  https://dl.k8s.io/v$VERSION/kubernetes-node-linux-amd64.tar.gz

echo "02-Fetched 1.29.12 kubernetes client, server, and node binaries."

{
  sudo tar -xvf kubernetes-node-linux-amd64.tar.gz -C .
  sudo mv ./kubernetes/node/bin/* /usr/local/bin/
  sudo rm -rf ./kubernetes
  sudo rm kubernetes-node-linux-amd64.tar.gz 

  sudo tar -xvf kubernetes-server-linux-amd64.tar.gz -C .
  sudo mv ./kubernetes/server/bin/* /usr/local/bin/
  sudo rm -rf ./kubernetes
  sudo rm kubernetes-server-linux-amd64.tar.gz

  sudo tar -xvf kubernetes-client-linux-amd64.tar.gz -C .
  sudo mv ./kubernetes/client/bin/* /usr/local/bin/
  sudo rm -rf ./kubernetes
  sudo rm kubernetes-client-linux-amd64.tar.gz

  chmod +x /usr/local/bin/*
}
echo "03-Installed kube-apiserver, kube-controller-manager, kube-scheduler, and kubectl."

{
  sudo mkdir -p /var/lib/kubernetes/

  sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
}
echo "04-Moved configuration files (ca, ca-key, etc.) to /var/lib/kubernetes/."

INTERNAL_IP=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show -g kubernetes \
  -n kubernetes-pip --query "ipAddress" -o tsv)
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local
echo "05-Internal IP Address for the compute instance: "$INTERNAL_IP



cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer=https://${PUBLIC_IP_ADDRESS}:6443 \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "06-Created the kube-apiserver.service systemd unit file."

sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --allocate-node-cidrs=true \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "07-Created the kube-controller-manager.service systemd unit file."

sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF


cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "08-Created the kube-scheduler.service systemd unit file."

{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
  sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
}
echo "09-Started services: kube-apiserver kube-controller-manager kube-scheduler ."
echo "10-Allow 12 seconds for all services to comeup....."
sleep 1

kubectl get componentstatuses --kubeconfig admin.kubeconfig
echo "11-Listed all services."


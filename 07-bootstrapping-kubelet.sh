#!/bin/bash

{
  sudo apt-get update
  sudo apt-get -y install socat conntrack ipset
}
echo "00-Installed OS dependencies."


{
  VERSION="1.29.0"
  wget -q --show-progress --https-only --timestamping \
    https://github.com/kubernetes-sigs/cri-tools/releases/download/v$VERSION/crictl-v$VERSION-linux-amd64.tar.gz
  sudo tar -xvf crictl-v$VERSION-linux-amd64.tar.gz -C /usr/local/bin/
  rm crictl-v$VERSION-linux-amd64.tar.gz
}

{
  VERSION="latest"

  wget -q --show-progress --https-only --timestamping \
    https://storage.googleapis.com/gvisor/releases/release/$VERSION/runsc
}

{
  VERSION="1.1.9"
  wget -q --show-progress --https-only --timestamping \
    https://github.com/opencontainers/runc/releases/download/v$VERSION/runc.amd64
  sudo mv runc.amd64 /usr/local/bin/runc
}

{
  VERSION="1.3.0"
  wget -q --show-progress --https-only --timestamping \
    https://github.com/containernetworking/plugins/releases/download/v$VERSION/cni-plugins-linux-amd64-v$VERSION.tgz
  sudo tar -xvf cni-plugins-linux-amd64-v$VERSION.tgz -C /opt/cni/bin/
  rm cni-plugins-linux-amd64-v$VERSION.tgz
}

{
  VERSION="1.7.5"
  mkdir containerd
  
  wget https://github.com/containerd/containerd/releases/download/v$VERSION/containerd-$VERSION-linux-amd64.tar.gz
  sudo tar -xvf containerd-$VERSION-linux-amd64.tar.gz  -C containerd
  sudo mv containerd/bin/* /bin/
  rm containerd-$VERSION-linux-amd64.tar.gz
  rm -rf containerd
}



VERSION="1.29.12"
wget -q --show-progress --https-only --timestamping \
  https://dl.k8s.io/v$VERSION/kubernetes-client-linux-amd64.tar.gz \
  https://dl.k8s.io/v$VERSION/kubernetes-node-linux-amd64.tar.gz

echo "02-Fetched 1.29.12 kubernetes client, server, and node binaries."

{
  sudo tar -xvf kubernetes-node-linux-amd64.tar.gz -C .
  sudo mv ./kubernetes/node/bin/* /usr/local/bin/
  sudo rm -rf ./kubernetes
  sudo rm kubernetes-node-linux-amd64.tar.gz 

  sudo tar -xvf kubernetes-client-linux-amd64.tar.gz -C .
  sudo mv ./kubernetes/client/bin/* /usr/local/bin/
  sudo rm -rf ./kubernetes
  sudo rm kubernetes-client-linux-amd64.tar.gz

  sudo chmod +x /usr/local/bin/*
}

echo "1-Fetched worker binaries crictl, runsc, runc, cni, containerd, kubectl, kube-proxy, and kubelet."

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes 

echo "02-Made directories for each worker binary."

#{
#  chmod +x kubectl kube-proxy kubelet runc runsc
#  sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
#}
echo "03-Installed worker binaries."

POD_CIDR="$(echo $(curl --silent -H Metadata:true "http://169.254.169.254/metadata/instance/compute/tags?api-version=2017-08-01&format=text" | sed 's/\;/\n/g' | grep pod-cidr) | cut -d : -f2)"
#cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
#{
#    "cniVersion": "0.4.0",
#    "name": "bridge",
#    "type": "bridge",
#    "bridge": "cnio0",
#    "isGateway": true,
#    "ipMasq": true,
#    "ipam": {
#        "type": "host-local",
#        "ranges": [
#          [{"subnet": "${POD_CIDR}"}]
#        ],
#        "routes": [{"dst": "0.0.0.0/0"}]
#    }
#}
#EOF


#cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
#{
#    "cniVersion": "0.4.0",
#    "name": "lo",
#    "type": "loopback"
#}
#EOF
echo "04-Configured CNI Networking."

sudo mkdir -p /etc/containerd/


cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
    [plugins.cri.containerd.gvisor]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
  [plugins."io.containerd.grpc.v1.cri".cni]
    bin_dir = "/opt/cni/bin"
    conf_dir = "/etc/cni/net.d"

EOF


cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd

Delegate=yes
KillMode=process
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

echo "05-Configured Containerd."

{
  sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  sudo mv ca.pem /var/lib/kubernetes/
  sudo mv calico* /opt/cni/bin/
  sudo mv 10-calico.conf /etc/cni/net.d/
}


cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


echo "06-Configured Kubelet."

sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig


cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF


cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF



echo "07-Configured kube-proxy."

{
  sudo systemctl daemon-reload
  sudo systemctl enable containerd kubelet kube-proxy
  sudo systemctl start containerd kubelet kube-proxy
}


echo "08-Started Worker Services kubelet, containerd, and kube-proxy."

{
  sudo mkdir -p /var/lib/calico
  sudo su -c 'hostname > /var/lib/calico/nodename'
}
echo "09-Created /var/lib/calico/nodename."


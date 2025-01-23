# az-kube-the-hardway-calico


First lets figure out all the versions:
1. ETCD : https://github.com/etcd-io/etcd/releases/tag/v3.5.12
2. Calico 3.29
3. Kubernetes v1.29 (https://www.downloadkubernetes.com/)

https://dl.k8s.io/v1.29.12/kubernetes-client-linux-amd64.tar.gz
 https://dl.k8s.io/v1.29.12/kubernetes-server-linux-amd64.tar.gz
 https://dl.k8s.io/v1.29.12/kubernetes-node-linux-amd64.tar.gz


VERSION="3.5.12"
"https://github.com/etcd-io/etcd/releases/download/v$VERSION/etcd-v$VERSION-linux-amd64.tar.gz"

VERSION="1.29.0"
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v$VERSION/crictl-v$VERSION-linux-amd64.tar.gz

VERSION="latest"
wget https://storage.googleapis.com/gvisor/releases/release/$VERSION/runsc
chmod +x runsc
mv runsc /usr/local/bin/

VERSION="1.1.9"
wget -q --show-progress --https-only --timestamping \
  https://github.com/opencontainers/runc/releases/download/$VERSION/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

VERSION="1.3.0"
wget -q --show-progress --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz \

VERSION="1.7.5"
wget https://github.com/containerd/containerd/releases/download/v$VERSION/containerd-$VERSION-linux-amd64.tar.gz
tar -xvf containerd-$VERSION-linux-amd64.tar.gz -C /usr/local


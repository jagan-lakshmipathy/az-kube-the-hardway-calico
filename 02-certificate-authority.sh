cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

echo '00-Created Root Configuration File.'


cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "Kubernetes",
      "OU": "MI",
      "ST": "Italy"
    }
  ]
}
EOF

echo '01-Created Root CSR File.'

cfssl gencert -initca ca-csr.json | cfssljson -bare ca


echo '02-Created Root private key and certificate.'


cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
EOF


echo '03-Created admin CSR file.'

 cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin


echo '04-Generated admin private key and certificate.'
ls -al admin*.pem


for instance in worker-0 worker-1; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
EOF

EXTERNAL_IP=$(az network public-ip show -g kubernetes \
  -n ${instance}-pip --query ipAddress -o tsv)

INTERNAL_IP=$(az vm show -d -n ${instance} -g kubernetes --query privateIps -o tsv)

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

echo '05-Generated worker private key and certificate.'
ls -al worker*.pem


{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}

echo '06-Generated kube-controller-manager private key and certificate.'
ls -al kube-controler-manager*.pem


cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milano",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
EOF

echo '07-Generated kube-proxy private key and certificate.'
ls -al kube-proxy*.pem


{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}



echo '08-Generated kube-scheduler private key and certificate.'
ls -al kube-scheduler*


KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show -g kubernetes \
  -n kubernetes-pip --query "ipAddress" -o tsv)

  echo 'Kubernetes IP:'$KUBERNETES_PUBLIC_ADDRESS

  cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
EOF

echo '09-Generated Kubernetes CSR'
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,10.240.0.20,10.240.0.21,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

echo '10-Generated Kubernetes Private Key and Certificate.'
ls -al kubernetes*.pem

{
  
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
EOF


echo '11-Generated service-account CSR.'

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}

echo '12-Generated service-account Private Key and Certificate.'
ls -al service-account*.pem

for instance in worker-0 worker-1; do
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes \
    -n ${instance}-pip --query "ipAddress" -o tsv)

  scp -o StrictHostKeyChecking=no ca.pem kubernetes-key.pem kubernetes.pem ${instance}-key.pem ${instance}.pem kuberoot@${PUBLIC_IP_ADDRESS}:~/
done
echo 'Copied client certificates to workers.'

for instance in controller-0 controller-1 controller-2; do
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes \
    -n ${instance}-pip --query "ipAddress" -o tsv)

  scp -o StrictHostKeyChecking=no ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem kuberoot@${PUBLIC_IP_ADDRESS}:~/
done

echo '13-Copied client certificates to Controllers.'

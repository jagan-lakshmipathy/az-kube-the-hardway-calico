#!/bin/zsh

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo "01-ENCRYPTION_KEY: "$ENCRYPTION_KEY

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo "02-Created encryption-config yaml"

for instance in controller-0 controller-1 controller-2; do
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes \
    -n ${instance}-pip --query "ipAddress" -otsv)

  scp -o StrictHostKeyChecking=no encryption-config.yaml kuberoot@${PUBLIC_IP_ADDRESS}:~/
  echo "03-Copied encryption-config yaml "${instance}
done



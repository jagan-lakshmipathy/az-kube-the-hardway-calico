#!/bin/zsh


cat <<EOF | tee env-controller.sh
#!/bin/bash
CONTROLLER0_IP=$(az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -otsv)
CONTROLLER1_IP=$(az network public-ip show -g kubernetes -n controller-1-pip --query "ipAddress" -otsv)
CONTROLLER2_IP=$(az network public-ip show -g kubernetes -n controller-2-pip --query "ipAddress" -otsv)

KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show -g kubernetes -n kubernetes-pip --query "ipAddress" -o tsv)

get_controller_ip() {
  case \$1 in
    controller-0)
      echo "\${CONTROLLER0_IP}"
      ;;
    controller-1)
      echo "\${CONTROLLER1_IP}"
      ;;
    controller-2)
      echo "\${CONTROLLER2_IP}"
      ;;
    *)
      echo "Invalid option"
      ;;
  esac
}

PUBLIC_IP_ADDRESS=\$(get_controller_ip "\$HOSTNAME")
echo "PUBLIC IP: "\$PUBLIC_IP_ADDRESS
echo "KUBERNETES IP: "\$KUBERNETES_PUBLIC_ADDRESS
EOF

chmod +x ./env-controller.sh
#!/bin/zsh

RG_NAME="kubernetes"
LOCATION="eastus"

# Create the resource group
az group create \
    --name $RG_NAME \
    --location $LOCATION


echo '0-Created resourceGroup kubernetes'

az network vnet create -g $RG_NAME \
  -n kubernetes-vnet \
  --address-prefix 10.240.0.0/24 \
  --subnet-name kubernetes-subnet \
  --location $LOCATION

echo '1-Created vnet kubernetes-net with subnet kubernetes-subnet'

az network nsg create -g $RG_NAME -n kubernetes-nsg --location $LOCATION
echo 'Created nsg kubernetes-nsg'

az network vnet subnet update -g $RG_NAME \
  -n kubernetes-subnet \
  --vnet-name kubernetes-vnet \
  --network-security-group kubernetes-nsg

echo '2-Updated subnet kubernetes-subnet with kubernetes-nsg'

az network nsg rule create -g $RG_NAME \
  -n kubernetes-allow-ssh \
  --access allow \
  --destination-address-prefix '*' \
  --destination-port-range 22 \
  --direction inbound \
  --nsg-name kubernetes-nsg \
  --protocol tcp \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --priority 1000

echo '3-Created nsg rule kubernetes-allow-ssh'

az network nsg rule create -g $RG_NAME \
  -n kubernetes-allow-api-server \
  --access allow \
  --destination-address-prefix '*' \
  --destination-port-range 6443 \
  --direction inbound \
  --nsg-name kubernetes-nsg \
  --protocol tcp \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --priority 1001

echo '4-Created nsg rule kubernetes-allow-api'

az network nsg rule list -g $RG_NAME --nsg-name kubernetes-nsg --query "[].{Name:name, \
  Direction:direction, Priority:priority, Port:destinationPortRange}" -o table

echo '5-Listed nsg rules'

az network lb create -g $RG_NAME \
  -n kubernetes-lb \
  --backend-pool-name kubernetes-lb-pool \
  --public-ip-zone 1 \
  --sku Standard \
  --public-ip-address kubernetes-pip \
  --public-ip-address-allocation static \
  --location $LOCATION

echo '6-Created lb kubernetes-lb'  

az network public-ip list --query="[?name=='kubernetes-pip'].{ResourceGroup:resourceGroup, \
  Region:location,Allocation:publicIPAllocationMethod,IP:ipAddress}" -o table

echo '7-Listed public-ip'


UBUNTULTS="Canonical:UbuntuServer:18.04-LTS:latest"

az vm availability-set create -g $RG_NAME -n controller-as

for i in 0 1 2; do
    echo "[Controller ${i}] Creating public IP..."
    az network public-ip create --sku Standard -z 1 -n controller-${i}-pip -g kubernetes > /dev/null

    echo "[Controller ${i}] Creating NIC..."
    az network nic create -g $RG_NAME \
        -n controller-${i}-nic \
        --private-ip-address 10.240.0.1${i} \
        --public-ip-address controller-${i}-pip \
        --location $LOCATION \
        --vnet kubernetes-vnet \
        --subnet kubernetes-subnet \
        --ip-forwarding \
        --lb-name kubernetes-lb \
        --lb-address-pools kubernetes-lb-pool > /dev/null

    echo "[Controller ${i}] Creating VM..."
    az vm create -g $RG_NAME \
        -n controller-${i} \
        --image ${UBUNTULTS} \
        --nics controller-${i}-nic \
        --location $LOCATION \
        --public-ip-sku Standard \
        --availability-set controller-as \
        --admin-username 'kuberoot' \
        --generate-ssh-keys > /dev/null
done

echo '8-Created 3 VMs with NIC for controllers'


az vm availability-set create -g $RG_NAME -n worker-as

for i in 0 1; do
    echo "[Worker ${i}] Creating public IP..."
    az network public-ip create --sku Standard -z 1 -n worker-${i}-pip -g kubernetes > /dev/null

    echo "[Worker ${i}] Creating NIC..."
    az network nic create -g kubernetes \
        -n worker-${i}-nic \
        --private-ip-address 10.240.0.2${i} \
        --public-ip-address worker-${i}-pip \
        --location $LOCATION \
        --vnet kubernetes-vnet \
        --subnet kubernetes-subnet \
        --ip-forwarding > /dev/null

    echo "[Worker ${i}] Creating VM..."
    az vm create -g $RG_NAME \
        -n worker-${i} \
        --image ${UBUNTULTS} \
        --nics worker-${i}-nic \
        --location $LOCATION \
        --public-ip-sku Standard \
        --tags pod-cidr=10.200.${i}.0/24 \
        --availability-set worker-as \
        --generate-ssh-keys \
        --admin-username 'kuberoot' > /dev/null
done

echo '9-Created 2 VMs with NIC for workers'


az vm list -d -g $RG_NAME -o table
echo '10-Listed vms'

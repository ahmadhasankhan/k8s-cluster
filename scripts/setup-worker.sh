#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "🔧 Installing worker dependencies..."

sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl lsb-release gnupg

sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

echo "🔧 Configuring kernel networking..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "🔑 Adding Kubernetes apt repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key -o /tmp/k8s-release.key
sudo install -m 644 /tmp/k8s-release.key /etc/apt/keyrings/k8s-release.asc

echo "deb [signed-by=/etc/apt/keyrings/k8s-release.asc] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "✅ Worker ready to join."

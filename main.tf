terraform {
  required_version = ">= 1.5.0"
}

locals {
  master_name  = "k8s-master"
  worker_names = ["k8s-worker1", "k8s-worker2"]
}

# 1️⃣  Create VMs
resource "null_resource" "create_vms" {
  provisioner "local-exec" {
    command = <<EOT
      echo "🚀 Launching VMs..."
      multipass launch --name ${local.master_name} --cpus 4 --mem 8G --disk 40G jammy
      for w in ${join(" ", local.worker_names)}; do
        multipass launch --name $w --cpus 2 --mem 4G --disk 30G jammy
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# 2️⃣  Setup Kubernetes master
resource "null_resource" "setup_master" {
  depends_on = [null_resource.create_vms]

  provisioner "local-exec" {
    command = <<EOT
      echo "🧠 Setting up Kubernetes master..."
      multipass transfer scripts/setup-master.sh ${local.master_name}:/home/ubuntu/
      multipass exec ${local.master_name} -- bash /home/ubuntu/setup-master.sh
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# 3️⃣  Fetch join command
resource "null_resource" "get_join_command" {
  depends_on = [null_resource.setup_master]

  provisioner "local-exec" {
    command = <<EOT
      echo "🔍 Fetching kubeadm join command..."
      multipass exec ${local.master_name} -- sudo kubeadm token create --print-join-command | sed 's/^/sudo /' > join.sh
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# 4️⃣  Setup and join workers
resource "null_resource" "setup_workers" {
  count      = length(local.worker_names)
  depends_on = [null_resource.get_join_command]

  provisioner "local-exec" {
    command = <<EOT
      WORKER=${element(local.worker_names, count.index)}
      echo "🔧 Configuring $WORKER..."
      multipass transfer scripts/setup-worker.sh $WORKER:/home/ubuntu/
      multipass exec $WORKER -- bash /home/ubuntu/setup-worker.sh
      echo "🔗 Joining $WORKER to cluster..."
      multipass transfer join.sh $WORKER:/home/ubuntu/
      multipass exec $WORKER -- sudo bash /home/ubuntu/join.sh
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# 5️⃣  Install Cilium automatically
resource "null_resource" "install_cilium" {
  depends_on = [null_resource.setup_workers]

  provisioner "local-exec" {
    command = <<EOT
      echo "🌐 Installing Cilium CNI (ARM64)..."
      multipass exec ${local.master_name} -- bash -c '
        set -eux
        CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/$${CLI_VERSION}/cilium-linux-arm64.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-arm64.tar.gz.sha256sum
        sudo tar xzvf cilium-linux-arm64.tar.gz -C /usr/local/bin
        sudo mv /usr/local/bin/cilium /usr/local/bin/cilium-cli || true
        sudo ln -sf /usr/local/bin/cilium-cli /usr/local/bin/cilium
        rm cilium-linux-arm64.tar.gz*
        cilium install --version 1.16.1 \
  --set kubeProxyReplacement=false \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
        cilium status --wait
      '
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}


# 6️⃣  Outputs
output "instructions" {
  value = <<EOT

✅ Kubernetes cluster created successfully!

To access your cluster:
  multipass shell ${local.master_name}
  kubectl get nodes -o wide

To clean up:
  terraform destroy -auto-approve

EOT
}

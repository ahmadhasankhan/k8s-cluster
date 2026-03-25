resource "null_resource" "install_cilium" {
  depends_on = [null_resource.setup_workers]

  provisioner "local-exec" {
    command = <<EOT
      echo "🌐 Installing Cilium..."
      multipass exec ${local.master_name} -- bash -c '
        set -eux
        CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/$${CLI_VERSION}/cilium-linux-arm64.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-arm64.tar.gz.sha256sum
        sudo tar xzvf cilium-linux-arm64.tar.gz -C /usr/local/bin
        sudo mv /usr/local/bin/cilium /usr/local/bin/cilium-cli || true
        sudo ln -sf /usr/local/bin/cilium-cli /usr/local/bin/cilium
        rm cilium-linux-arm64.tar.gz*
        cilium install --version 1.16.1 --set kubeProxyReplacement=false --set hubble.relay.enabled=true --set hubble.ui.enabled=true
        cilium status --wait
      '
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "install_longhorn" {
  depends_on = [null_resource.install_metallb]

  provisioner "local-exec" {
    command = <<EOT
      echo "💾 Installing Longhorn..."
      multipass exec ${local.master_name} -- bash -c '
        set -eux
        kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.1/deploy/longhorn.yaml
        kubectl wait -n longhorn-system --for=condition=available deploy/longhorn-driver-deployer --timeout=300s
      '
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "install_ingress" {
  depends_on = [null_resource.install_cilium]

  provisioner "local-exec" {
    command = <<EOT
      echo "🌐 Installing NGINX Ingress Controller..."
      multipass exec ${local.master_name} -- bash -c '
        set -eux
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
        kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s
      '
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

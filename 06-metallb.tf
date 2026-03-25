resource "null_resource" "install_metallb" {
  depends_on = [null_resource.install_ingress]

  provisioner "local-exec" {
    command = <<EOT
      echo "⚙️ Installing MetalLB..."
      multipass exec ${local.master_name} -- bash -c '
        set -eux
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
        kubectl wait --namespace metallb-system --for=condition=available deploy/controller --timeout=180s
        cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: default
spec:
  addresses:
  - 192.168.64.100-192.168.64.200
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  namespace: metallb-system
  name: default
EOF
      '
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

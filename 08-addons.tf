######################################
#  Addons: Cert-Manager, Monitoring,
#  Storage, and Argo CD
######################################

# 🧩 CERT-MANAGER INSTALLATION
resource "null_resource" "install_cert_manager" {
  depends_on = [null_resource.install_longhorn]

  provisioner "local-exec" {
    command = <<EOT
    echo "🔐 Installing cert-manager (with retry)..."
    for i in {1..5}; do
      if multipass info ${local.master_name} &>/dev/null; then
        multipass exec ${local.master_name} -- bash -c '
          set -eux
          kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${local.cert_manager_version}/cert-manager.yaml
          kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=300s
        '
        exit 0
      fi
      echo "⏳ Waiting for ${local.master_name} to be reachable ($i/5)..."
      sleep 10
    done
    echo "❌ ${local.master_name} unreachable after 5 attempts" >&2
    exit 1
  EOT
    interpreter = ["/bin/bash", "-c"]
  }
}


# 📈 PROMETHEUS + GRAFANA (MONITORING)
resource "null_resource" "install_prometheus_stack" {
  depends_on = [null_resource.install_cert_manager]

  provisioner "local-exec" {
    command = <<EOT
    echo "🔍 Checking connectivity to ${local.master_name}..."
    for i in {1..10}; do
      multipass exec ${local.master_name} -- echo ok && break
      echo "⏳ VM not reachable yet, retrying..."
      sleep 5
    done
    echo "📊 Installing kube-prometheus-stack (Prometheus + Grafana)..."
    multipass exec ${local.master_name} -- bash -c '
      set -eux
      helm repo add ${local.prometheus_stack_repo} https://prometheus-community.github.io/helm-charts
      helm repo update
      kubectl create ns monitoring --dry-run=client -o yaml | kubectl apply -f -
      helm upgrade --install kube-prometheus-stack ${local.prometheus_stack_repo}/${local.prometheus_stack_chart} \
        --namespace monitoring \
        --set grafana.service.type=NodePort \
        --set grafana.defaultDashboardsEnabled=true \
        --set prometheus.service.type=ClusterIP \
        --wait --timeout 15m
    '
  EOT
    interpreter = ["/bin/bash", "-c"]
  }

}

# ⚙️ LONGHORN AS DEFAULT STORAGE CLASS
resource "null_resource" "set_longhorn_default_storageclass" {
  depends_on = [null_resource.install_prometheus_stack]

  provisioner "local-exec" {
    command = <<EOT
      echo "💾 Setting Longhorn as default StorageClass..."
      multipass exec ${local.master_name} -- bash -c '
        set -eux
        kubectl patch storageclass longhorn -p "{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}" || true
      '
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# 🚀 ARGO CD (GITOPS)
resource "null_resource" "install_argocd" {
  depends_on = [null_resource.set_longhorn_default_storageclass]

  provisioner "local-exec" {
    command = <<EOT
      echo "🚀 Installing Argo CD..."
      multipass exec ${local.master_name} -- bash -c '
        set -eux
        kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${local.argocd_version}/manifests/install.yaml
        kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

        # Expose ArgoCD via NodePort (safe for Multipass/macOS)
        kubectl -n argocd patch svc argocd-server -p "{\"spec\":{\"type\":\"${local.argocd_svc_type}\"}}"
      '
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# 🧪 FINAL CHECK & SUMMARY
resource "null_resource" "addons_summary" {
  depends_on = [null_resource.install_argocd]

  provisioner "local-exec" {
    command = <<EOT
multipass exec k8s-master -- bash -c '
set -eux
echo ""
echo "=========================="
echo "✅ Addons Installed"
echo "=========================="
echo "- cert-manager (ClusterIssuer: selfsigned)"
echo "- Prometheus + Grafana (NodePort)"
echo "- Longhorn (default StorageClass)"
echo "- Argo CD (UI exposed via ${local.argocd_svc_type})"
echo ""
echo "Grafana access:"
echo "  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
echo "  → http://localhost:3000  (user: admin, pass: prom-operator)"
echo ""
echo "ArgoCD access:"
echo "  kubectl -n argocd get svc argocd-server"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
'
EOT
interpreter = ["/bin/bash", "-c"]
}
}

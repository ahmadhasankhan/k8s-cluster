output "cluster_summary" {
  value = <<EOT
✅ Cluster Ready! Components Installed:
   - Kubernetes multi-node cluster
   - Cilium CNI + Hubble
   - NGINX Ingress Controller
   - MetalLB LoadBalancer IPs (192.168.64.100–200)
   - Longhorn Persistent Storage

Access Hubble UI:  http://localhost:12000
Deploy your app:   kubectl apply -f your-deployment.yaml
Create ingress:    kubectl apply -f your-ingress.yaml
EOT
}

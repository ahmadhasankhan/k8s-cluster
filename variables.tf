terraform {
  required_version = ">= 1.5.0"
}

locals {
  master_name  = "k8s-master"
  worker_names = ["k8s-worker1", "k8s-worker2"]

  # Versions and configuration
  cert_manager_version   = "v1.14.5"
  prometheus_stack_chart = "kube-prometheus-stack"
  prometheus_stack_repo  = "prometheus-community"
  longhorn_chart         = "longhorn"
  longhorn_repo          = "longhorn/longhorn"
  longhorn_version       = "1.6.2"
  argocd_version         = "v2.12.3"
  argocd_svc_type        = "NodePort" # Use LoadBalancer for bridged networking
}
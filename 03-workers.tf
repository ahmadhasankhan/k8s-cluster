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

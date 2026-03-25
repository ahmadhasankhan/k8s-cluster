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

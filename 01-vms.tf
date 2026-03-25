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

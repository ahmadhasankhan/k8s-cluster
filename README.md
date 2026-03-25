# k8s-cluster

## Configure Kubectl connection from local machine

```bash
  multipass exec k8s-master -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config
```
### Common Commands
```bash
# Get ingress service

kubectl get svc -n ingress-nginx

```




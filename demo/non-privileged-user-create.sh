alias kubectl="./artifacts/k3s-binary-v1.20.5+k3s1 kubectl --kubeconfig ./artifacts/k3s-kube-config"
kubectl create namespace unprivileged-user
kubectl create serviceaccount -n unprivileged-user fake-user
kubectl create rolebinding -n unprivileged-user fake-editor --clusterrole=edit --serviceaccount=unprivileged-user:fake-user

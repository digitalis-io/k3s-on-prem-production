#!/bin/sh
node=${1}
if [ -n "${node}" ]; then
    nodeSelector='"nodeSelector": { "kubernetes.io/hostname": "'${node:?}'" },'
else
    nodeSelector=""
fi
set -x
 ./artifacts/k3s-binary-v1.20.5+k3s1 kubectl --kubeconfig ./artifacts/k3s-kube-config --as=system:serviceaccount:unprivileged-user:fake-user -n unprivileged-user run ${USER+${USER}-}sudo --restart=Never -it  --image overriden --overrides '
{
  "spec": {
    "hostPID": true,
    "hostNetwork": true,
    '"${nodeSelector?}"'
    "containers": [
      {
        "name": "busybox",
        "image": "alpine:3.7",
        "command": ["nsenter", "--mount=/proc/1/ns/mnt", "--", "sh", "-c", "hostname sudo--$(cat /etc/hostname); exec /bin/bash"],
        "stdin": true,
        "tty": true,
        "resources": {"requests": {"cpu": "10m"}},
        "securityContext": {
          "privileged": true
        }
      }
    ]
  }
}' --rm --attach

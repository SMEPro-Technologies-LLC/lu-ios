# Kubernetes Setup — RKE2 on Lamar University Infrastructure

IOSME uses **RKE2** (Rancher Kubernetes Engine 2) as the Kubernetes distribution. RKE2 is chosen for its FIPS compliance, embedded etcd, and simplified air-gap support.

---

## Architecture

```
                    ┌─────────────────────────────┐
                    │   External Load Balancer      │
                    │   (F5 / HAProxy — LU IT)      │
                    └────────────┬────────────────┘
                                 │ 443 / 6443
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                   ▼
       iosme-master-01   iosme-master-02   iosme-master-03
       (control plane)   (control plane)   (control plane)
              │                  │                   │
              └──────────────────┼───────────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                   ▼
       iosme-worker-01   iosme-worker-02   iosme-gpu-01
       (general)         (general)         (GPU inference)
```

---

## Installation

### Server (Control Plane) Nodes

```bash
# Run on iosme-master-01 first
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=server sh -

mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<EOF
tls-san:
  - iosme-master-01.lamar.edu
  - iosme-master-02.lamar.edu
  - iosme-master-03.lamar.edu
  - iosme-k8s.lamar.edu          # VIP / LB FQDN
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16
cni: canal
disable:
  - rke2-ingress-nginx           # We deploy ingress-nginx via Helm
EOF

systemctl enable rke2-server.service
systemctl start rke2-server.service

# Get the join token for additional masters/agents
cat /var/lib/rancher/rke2/server/node-token
```

```bash
# Run on iosme-master-02 and iosme-master-03
cat > /etc/rancher/rke2/config.yaml <<EOF
server: https://iosme-master-01.lamar.edu:9345
token: <TOKEN_FROM_MASTER_01>
tls-san:
  - iosme-k8s.lamar.edu
EOF

systemctl enable rke2-server.service
systemctl start rke2-server.service
```

### Agent (Worker) Nodes

```bash
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -

cat > /etc/rancher/rke2/config.yaml <<EOF
server: https://iosme-k8s.lamar.edu:9345
token: <TOKEN_FROM_MASTER_01>
EOF

# For GPU node, add node label:
# node-label:
#   - "nvidia.com/gpu=true"

systemctl enable rke2-agent.service
systemctl start rke2-agent.service
```

---

## kubeconfig Setup

```bash
# On the first master node
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Copy to operations workstation / bastion
scp root@iosme-master-01:/etc/rancher/rke2/rke2.yaml ~/.kube/iosme-prod.yaml
# Edit server address to point to the LB
sed -i 's/127.0.0.1/iosme-k8s.lamar.edu/' ~/.kube/iosme-prod.yaml
export KUBECONFIG=~/.kube/iosme-prod.yaml

kubectl get nodes
```

---

## Namespaces

```bash
kubectl create namespace iosme-prod
kubectl create namespace iosme-staging
kubectl create namespace iosme-dev
kubectl create namespace monitoring
kubectl create namespace cert-manager
kubectl create namespace ingress-nginx
```

---

## Core Add-ons Deployment Order

1. **cert-manager** — TLS certificate management
2. **ingress-nginx** — Ingress controller
3. **longhorn** or **NFS Provisioner** — Persistent storage
4. **kube-prometheus-stack** — Monitoring (see [Observability docs](observability.md))
5. **iosme-lamar** — Application Helm chart (see [Helm Deployment docs](helm-deployment.md))

---

## Node Labels & Taints

```bash
# Label GPU node
kubectl label node iosme-gpu-01 node-role.iosme/gpu=true accelerator=nvidia

# Taint GPU node so only GPU workloads schedule there
kubectl taint node iosme-gpu-01 nvidia.com/gpu=present:NoSchedule
```

---

## etcd Backup

RKE2 performs automatic etcd snapshots to `/var/lib/rancher/rke2/server/db/snapshots/`. Snapshots are also shipped to S3-compatible storage (MinIO on LU infrastructure):

```bash
# Manual snapshot
rke2 etcd-snapshot save --name manual-$(date +%Y%m%d%H%M%S)

# List snapshots
rke2 etcd-snapshot list
```

---

## Upgrading RKE2

```bash
# Check current version
rke2 --version

# Upgrade (sequential: masters first, then agents)
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.30.x+rke2r1 sh -
systemctl restart rke2-server  # or rke2-agent on worker nodes
```

---

## References

- [RKE2 Documentation](https://docs.rke2.io)
- [Runbook 01 — VM Provisioning](../runbooks/01-vm-provisioning.md)
- [Runbook 02 — Helm Deploy/Upgrade/Rollback](../runbooks/02-helm-deploy-upgrade-rollback.md)

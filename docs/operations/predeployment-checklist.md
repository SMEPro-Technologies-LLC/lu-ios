# Pre-deployment Validation Checklist

Use this checklist before deploying the `iosme-lamar` Helm chart to a cluster.

## 1. Verify cluster health

```bash
kubectl get nodes -o wide
```

Expected:
- 6 nodes in `Ready` state
- Node labels match any chart node selectors or affinity rules

## 2. Verify storage classes

```bash
kubectl get storageclass
```

Expected:
- `ios-san-fast` present with `Retain` reclaim policy and `AllowVolumeExpansion`
- `ios-san-standard` present

## 3. Verify Vault connectivity

If using External Secrets Operator / Vault-backed secrets:

```bash
vault status
```

Expected:
- `sealed=false`

## 4. Verify GPU node

If GPU workloads are enabled:

```bash
kubectl get nodes -l node-role.kubernetes.io/gpu=true
kubectl describe node lu-ios-gpu-01 | grep nvidia.com/gpu
```

Expected:
- GPU node is returned by the label selector
- `nvidia.com/gpu: 2` is reported on `lu-ios-gpu-01`

## 5. Verify ingress controller

```bash
kubectl get pods -n ingress-nginx
```

Expected:
- NGINX Ingress Controller pods are `Running`

## 6. Verify cert-manager

```bash
kubectl get pods -n cert-manager
```

Expected:
- `cert-manager`, `cainjector`, and `webhook` pods are `Running`

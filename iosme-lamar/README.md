# iosme-lamar — Operational Runbook

**Chart:** `iosme-lamar` v1.0.0  
**Document:** SME-IOS-LU-HELM-PROD-001  
**Target:** RKE2 / vanilla Kubernetes on RHEL 9 (VMware vSphere)  
**Namespace:** `iosme`

---

## Overview

`iosme-lamar` is the Helm chart for the **Intelligence Orchestration System (IOS+) — Lamar University Edition**. It deploys the full IOS+ middleware stack into the `iosme` Kubernetes namespace:

| Component | Kubernetes Resource | Replicas (prod) |
|-----------|-------------------|-----------------|
| API Gateway + Policy Engine | Deployment (`-api`) | 2 |
| Celery Worker Pool | Deployment (`-worker`) | 2 |
| LTI 1.3 Tool Provider | Deployment (`-lti-service`) | 1 |
| PostgreSQL 15 | StatefulSet (`-postgres`) | 2 (primary + replica) |
| Redis 7 | Deployment (`-redis`) | 1 |
| Alembic Migrations | Job (post-install/upgrade hook) | 1 (runs once) |

Supporting resources: Namespace, ConfigMap, Secrets (placeholder), Ingress, HPA (disabled by default), PodDisruptionBudgets, NetworkPolicies, ServiceAccount, Role/RoleBinding.

---

## Values Files

| File | Purpose |
|------|---------|
| `values.yaml` | **Reference/default only — DO NOT use in production.** Provides sensible defaults for `helm template` dry-runs and local development rendering. |
| `values-lamar-prod.yaml` | Production overrides for Lamar University. Use this file for all production deployments. |
| `values-lamar-dev.yaml` | Development/integration overrides — reduced replicas, relaxed resource limits, optional TLS. |

---

## Prerequisites

Before deploying, verify the following on the target cluster:

```bash
# 1. All six nodes are Ready and labelled correctly
kubectl get nodes -o wide
# Expected: k8s-api-01 through k8s-gpu-01 all in Ready state

# 2. Storage classes exist
kubectl get storageclass
# Required for prod: ios-san-fast (Retain, AllowVolumeExpansion), ios-san-standard

# 3. NGINX Ingress Controller is running
kubectl get pods -n ingress-nginx

# 4. cert-manager is running (if TLS is enabled)
kubectl get pods -n cert-manager

# 5. HashiCorp Vault is reachable (if secrets.source=vault)
vault status
# Expected: sealed=false, HA enabled

# 6. (Optional) GPU node label if GPU inference is required
kubectl get nodes -l node-role.kubernetes.io/gpu=true
```

---

## Secret Management

All production secret values are managed externally — **never commit real credentials to this repository**.

### Option A — External Secrets Operator + HashiCorp Vault (recommended)

1. Install ESO into the cluster.
2. Create an `ExternalSecret` for each secret listed in `templates/secret.yaml`, pointing to the corresponding Vault path (see annotations on each Secret template).
3. Set `secrets.source: vault` in `values-lamar-prod.yaml`.

### Option B — helm-secrets / SOPS

Encrypt a separate `secrets.yaml` file using SOPS and pass it with `-f secrets.yaml` at deploy time.

### Option C — Manual (development only)

Set `secrets.source: manual` and apply Kubernetes Secrets directly using `kubectl apply` before running Helm.

---

## Install

```bash
# Clone the repository
git clone https://github.com/SMEPro-Technologies-LLC/lu-ios.git
cd lu-ios

# Dry-run to validate the rendered manifests
helm install iosme-lamar ./iosme-lamar \
  -f iosme-lamar/values-lamar-prod.yaml \
  --namespace iosme \
  --create-namespace \
  --dry-run --debug

# Production deployment
helm install iosme-lamar ./iosme-lamar \
  -f iosme-lamar/values-lamar-prod.yaml \
  --namespace iosme \
  --create-namespace \
  --wait \
  --timeout 600s
```

### Post-install verification

```bash
# Check that the migrations job completed
kubectl get jobs -n iosme
# Expected: iosme-lamar-migrations  1/1  COMPLETE

# Verify all pods are Running
kubectl get pods -n iosme

# Check ingress
kubectl get ingress -n iosme
```

---

## Upgrade

```bash
# Review the pending diff (requires helm-diff plugin)
helm diff upgrade iosme-lamar ./iosme-lamar \
  -f iosme-lamar/values-lamar-prod.yaml

# Apply the upgrade
helm upgrade iosme-lamar ./iosme-lamar \
  -f iosme-lamar/values-lamar-prod.yaml \
  --namespace iosme \
  --wait \
  --timeout 600s
```

---

## Rollback

```bash
# List revision history
helm history iosme-lamar -n iosme

# Roll back to a specific revision
helm rollback iosme-lamar <REVISION> -n iosme --wait
```

---

## Uninstall

```bash
helm uninstall iosme-lamar -n iosme
# Note: PersistentVolumeClaims are NOT deleted automatically.
# To delete PVCs (DATA LOSS):
kubectl delete pvc -n iosme -l app.kubernetes.io/instance=iosme-lamar
```

---

## Local Render (no cluster required)

```bash
# Render all manifests to stdout using default values
helm template iosme-lamar ./iosme-lamar

# Render using production values
helm template iosme-lamar ./iosme-lamar \
  -f iosme-lamar/values-lamar-prod.yaml

# Lint the chart
helm lint ./iosme-lamar -f iosme-lamar/values-lamar-prod.yaml
```

---

## §08 Compliance Hard Constraints

The following values are contractual hard constraints (per SME-IOS-LU-FINAL-001 §08). They **must never** be changed without an approved Change Request from the Lamar Provost office:

| Value | Required Setting | Clause |
|-------|-----------------|--------|
| `compliance.bannerDirectMutation` | `false` | §08 Banner Integrity |
| `compliance.copilotInterception` | `false` | §08 Copilot Audit-Only |
| `compliance.blockchainAnchor` | `false` | §08 Blockchain disabled |
| `IOS_FEATURE_ENABLE_BLOCKCHAIN_ANCHOR` (ConfigMap) | `"false"` | §08 Blockchain disabled |
| `COPILOT_INTERCEPTION_ENABLED` (ConfigMap) | `"false"` | §08 Copilot Audit-Only |
| `BANNER_DIRECT_MUTATION` (ConfigMap) | `"false"` | §08 Banner Integrity |

---

## Directory Structure

```
iosme-lamar/
├── Chart.yaml                       # Chart metadata and version
├── values.yaml                      # Reference defaults — DO NOT USE IN PROD
├── values-lamar-prod.yaml           # Production overrides
├── values-lamar-dev.yaml            # Development overrides
├── README.md                        # This file
├── templates/
│   ├── _helpers.tpl                 # Common labels, selectors, naming helpers
│   ├── namespace.yaml               # iosme namespace
│   ├── configmap.yaml               # Feature flags, thresholds, compliance config
│   ├── secret.yaml                  # Placeholder secrets (Vault-backed in prod)
│   ├── api-deployment.yaml          # API Gateway + Policy Engine
│   ├── api-service.yaml             # ClusterIP for API pods
│   ├── worker-deployment.yaml       # Celery worker pool
│   ├── postgres-statefulset.yaml    # PostgreSQL 15 primary + replica
│   ├── postgres-service.yaml        # Headless + ClusterIP services for Postgres
│   ├── redis-deployment.yaml        # Redis 7 cache/queue
│   ├── redis-service.yaml           # ClusterIP for Redis
│   ├── ingress.yaml                 # NGINX Ingress + TLS + cert-manager
│   ├── hpa.yaml                     # HorizontalPodAutoscaler (disabled by default)
│   ├── lti-service-deployment.yaml  # LTI 1.3 Tool Provider
│   ├── lti-service-service.yaml     # ClusterIP for LTI service
│   ├── network-policies.yaml        # Default-deny + allow rules
│   ├── serviceaccount.yaml          # RBAC service account
│   ├── rbac.yaml                    # Role + RoleBinding
│   ├── pdb.yaml                     # PodDisruptionBudgets
│   └── migrations-job.yaml          # Alembic post-install/upgrade hook
├── crds/                            # Empty — no CRDs at v1.0.0
└── charts/                          # Subchart dependencies — empty at v1.0.0
```

---

## Version History

| Version | Description |
|---------|-------------|
| 1.0.0 | Initial scaffold — all core resources, placeholder secrets, compliance guards |

---

*Maintained by SMEPro Technologies LLC · platform@smepro.io*

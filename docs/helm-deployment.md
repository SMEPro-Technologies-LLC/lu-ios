# Helm Deployment — IOSME at Lamar University

This document covers deploying, upgrading, and rolling back the `iosme-lamar` Helm chart.

---

## Chart Location

The chart source lives at [`helm/iosme-lamar/`](../helm/iosme-lamar/). It was transferred from SMEPro Technologies and customized for Lamar University's environment.

---

## Chart Overview

| Field | Value |
|-------|-------|
| Chart Name | `iosme-lamar` |
| Application | IOSME iOS Mobile Experience |
| Helm Version | 3.14+ |
| Default Namespace | `iosme-prod` |
| Ingress | `iosme.lamar.edu` |

---

## Prerequisites

```bash
# Verify Helm is installed
helm version

# Add any required Helm repositories
helm repo add jetstack https://charts.jetstack.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

---

## Environment-Specific Values Files

```
helm/iosme-lamar/
├── Chart.yaml
├── values.yaml           ← default / base values
├── values-prod.yaml      ← production overrides
├── values-staging.yaml   ← staging overrides
└── values-dev.yaml       ← development overrides
```

---

## Initial Deployment

```bash
# Create namespace (if not already done)
kubectl create namespace iosme-prod

# Create required secrets first (see Secret Management docs)
# Then deploy:
helm upgrade --install iosme-lamar ./helm/iosme-lamar \
  --namespace iosme-prod \
  --values helm/iosme-lamar/values.yaml \
  --values helm/iosme-lamar/values-prod.yaml \
  --set image.tag=2.5.0 \
  --atomic \
  --timeout 10m \
  --create-namespace
```

---

## Upgrade

```bash
# Upgrade to a new version
helm upgrade iosme-lamar ./helm/iosme-lamar \
  --namespace iosme-prod \
  --values helm/iosme-lamar/values.yaml \
  --values helm/iosme-lamar/values-prod.yaml \
  --set image.tag=2.6.0 \
  --atomic \
  --timeout 10m
```

---

## Rollback

```bash
# List release history
helm history iosme-lamar --namespace iosme-prod

# Rollback to previous revision
helm rollback iosme-lamar --namespace iosme-prod

# Rollback to a specific revision
helm rollback iosme-lamar 3 --namespace iosme-prod
```

---

## Checking Release Status

```bash
helm status iosme-lamar --namespace iosme-prod
helm get values iosme-lamar --namespace iosme-prod
helm get manifest iosme-lamar --namespace iosme-prod | kubectl diff -f -
```

---

## Uninstall

```bash
# Remove the Helm release (keeps PVCs and secrets by default)
helm uninstall iosme-lamar --namespace iosme-prod
```

---

## Using the deploy script

The [`scripts/deploy-iosme.sh`](../scripts/deploy-iosme.sh) script wraps the Helm commands above:

```bash
# Deploy to production
./scripts/deploy-iosme.sh --env prod --version 2.5.0

# Deploy to staging
./scripts/deploy-iosme.sh --env staging --version 2.5.0-rc1

# Rollback production to the previous revision
./scripts/deploy-iosme.sh --env prod --rollback
```

---

## References

- [Helm Chart Source](../helm/iosme-lamar/)
- [Secret Management](secret-management.md)
- [Runbook 02 — Helm Deploy/Upgrade/Rollback](../runbooks/02-helm-deploy-upgrade-rollback.md)

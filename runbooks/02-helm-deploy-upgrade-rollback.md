# Runbook 02 — Helm Deploy / Upgrade / Rollback

**Applies to**: Lamar University IOSME  
**Scope**: Deploying new IOSME versions, upgrading the Helm chart, and rolling back  
**On-Call Level**: Level 2 (LU DevOps)  
**Estimated Time**: 15–30 minutes  

---

## Prerequisites

- [ ] `kubectl` configured with `iosme-prod` context
- [ ] `helm` 3.14+ installed
- [ ] This repository checked out with latest changes
- [ ] Target image version available in `registry.lamar.edu/iosme/app:<VERSION>`

---

## Pre-Deployment Checklist

```bash
# 1. Verify cluster health
kubectl get nodes
kubectl get pods -n iosme-prod

# 2. Check current Helm release
helm status iosme-lamar -n iosme-prod
helm history iosme-lamar -n iosme-prod

# 3. Verify target image exists
docker pull registry.lamar.edu/iosme/app:<VERSION>
```

---

## Deploy / Upgrade

### Using the deploy script (recommended)

```bash
./scripts/deploy-iosme.sh --env prod --version <VERSION>
```

### Manual Helm command

```bash
helm upgrade --install iosme-lamar ./helm/iosme-lamar \
  --namespace iosme-prod \
  --values helm/iosme-lamar/values.yaml \
  --values helm/iosme-lamar/values-prod.yaml \
  --set image.tag=<VERSION> \
  --atomic \
  --timeout 10m
```

`--atomic` ensures the release is automatically rolled back if it fails to deploy within the timeout.

---

## Post-Deployment Verification

```bash
# 1. Check pod rollout
kubectl rollout status deployment/iosme-app -n iosme-prod

# 2. Verify all pods are running
kubectl get pods -n iosme-prod

# 3. Check application health endpoint
curl -sf https://iosme.lamar.edu/health | jq .

# 4. Run smoke test
./scripts/health-check.sh --env prod

# 5. Check logs for errors
kubectl logs -l app=iosme-app -n iosme-prod --tail=100 | grep -i error
```

---

## Rollback

### If Helm `--atomic` rolled back automatically

The previous version is already running. Investigate the failure:

```bash
kubectl describe pods -n iosme-prod | grep -A 10 "Events:"
kubectl logs -l app=iosme-app -n iosme-prod --previous
```

### Manual rollback

```bash
# List revisions
helm history iosme-lamar -n iosme-prod

# Roll back to previous revision
helm rollback iosme-lamar -n iosme-prod

# Roll back to a specific revision
helm rollback iosme-lamar <REVISION> -n iosme-prod

# Using the deploy script
./scripts/deploy-iosme.sh --env prod --rollback
```

---

## Upgrade staging → production workflow

1. Deploy to staging first:
   ```bash
   ./scripts/deploy-iosme.sh --env staging --version <VERSION>
   ./scripts/health-check.sh --env staging
   ```
2. Observe for 30 minutes; check dashboards at https://grafana-iosme.lamar.edu.
3. If staging is healthy, deploy to production:
   ```bash
   ./scripts/deploy-iosme.sh --env prod --version <VERSION>
   ```
4. Verify production health (see Post-Deployment Verification above).

---

## Common Failure Scenarios

| Symptom | Cause | Remediation |
|---------|-------|-------------|
| `ImagePullBackOff` | Image not in registry | Verify image tag and registry reachability |
| `CrashLoopBackOff` | Application startup error | `kubectl logs pod/<POD_NAME> -n iosme-prod` |
| `OOMKilled` | Memory limit too low | Increase `resources.limits.memory` in values file |
| Helm timeout | Slow pod startup | Increase `--timeout`; check node resources |
| DB migration failure | Schema migration error | Check init container logs; may need manual DB intervention |

---

## Escalation

| Condition | Action |
|-----------|--------|
| Application bugs in new version | Roll back and notify SMEPro (support@smepro.com) |
| Infrastructure failure during deploy | Engage LU IT on-call |
| Database migration failure | Escalate to Level 3 (SMEPro DB team) |

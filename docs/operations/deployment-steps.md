# Deployment Steps

Use these steps to deploy the `iosme-lamar` Helm chart.

## Clone the repository

```bash
git clone https://github.com/Lamar-University/iosme-charts.git
cd iosme-charts
```

## Review production values

```bash
cat values-lamar-prod.yaml
```

## Dry-run to validate

```bash
helm install iosme-lamar ./iosme-lamar \
  -f values-lamar-prod.yaml \
  --namespace iosme \
  --create-namespace \
  --dry-run --debug
```

## Actual deployment

```bash
helm install iosme-lamar ./iosme-lamar \
  -f values-lamar-prod.yaml \
  --namespace iosme \
  --create-namespace \
  --wait \
  --timeout 600s
```

## Post-deployment verification

### Verify migrations ran

```bash
kubectl get jobs -n iosme
```

Expected:
- `iosme-lamar-migrations` shows `COMPLETE`

### Verify all pods

```bash
kubectl get pods -n iosme
```

Expected:
- 2× api
- 2× worker
- 2× postgres
- 1× redis
- 1× lti-service
- 1× gpu-inference

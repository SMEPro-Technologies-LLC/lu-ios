# Upgrade Steps

Use these steps to upgrade the deployed `iosme-lamar` Helm release.

## Pull updated chart

```bash
git pull origin main
```

## Review diff

```bash
helm diff upgrade iosme-lamar ./iosme-lamar -f values-lamar-prod.yaml
```

## Upgrade

```bash
helm upgrade iosme-lamar ./iosme-lamar \
  -f values-lamar-prod.yaml \
  --namespace iosme \
  --wait \
  --timeout 600s
```

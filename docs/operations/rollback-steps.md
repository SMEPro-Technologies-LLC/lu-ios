# Rollback Steps

Use these steps to inspect release history and roll back the deployed `iosme-lamar` Helm release.

## List revisions

```bash
helm history iosme-lamar -n iosme
```

## Roll back to previous revision

```bash
helm rollback iosme-lamar [REVISION] -n iosme
```

# manifests/

This directory contains **standalone Kubernetes manifests** — raw YAML files used for
initial cluster bootstrapping, one-off debugging, or reference during chart development.

> **Note:** These files are *not* the production deployment artifacts.
> The canonical production deployment is managed by the Helm chart in [`iosme-lamar/`](../iosme-lamar/),
> which contains equivalent (and more fully templated) resources under `templates/`.

## Contents

| File | Purpose |
|------|---------|
| `namespace.yaml` | Namespace declaration for `iosme` |
| `api-deployment.yaml` | API service Deployment |
| `worker-deployment.yaml` | Celery worker Deployment |
| `postgres-statefulset.yaml` | PostgreSQL StatefulSet |
| `redis-deployment.yaml` | Redis Deployment |
| `migrations-job.yaml` | Alembic migrations Job |
| `ingress.yaml` | Ingress resource |
| `network-policies.yaml` | Namespace-scoped NetworkPolicy rules |
| `GlobalNetworkPolicy.yaml` | Cluster-wide Calico GlobalNetworkPolicy |
| `certmanager.yaml` | cert-manager ClusterIssuer / Certificate |
| `secret.yaml` | Placeholder Secret (do not commit real values) |

## Usage

Apply individually for debugging or bootstrapping:

```bash
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/
```

For production deployments, always use the Helm chart:

```bash
helm upgrade --install iosme-lamar ./iosme-lamar \
  -f iosme-lamar/values-lamar-prod.yaml \
  --namespace iosme --create-namespace
```

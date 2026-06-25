# Concourse CI/CD Integration — IOSME

Lamar University uses **Concourse CI** to automate the build, test, and deployment pipeline for IOSME.

---

## Concourse Instance

| Field | Value |
|-------|-------|
| URL | https://concourse.lamar.edu |
| Team | `iosme` |
| Auth | LDAP (LU Active Directory) |

---

## Pipeline Overview

```
┌─────────────────────────────────────────────────────────┐
│                   iosme-deploy pipeline                  │
├─────────┬───────────┬────────────┬──────────────────────┤
│  source  │   build   │   test     │      deploy          │
│  (git)   │ (Docker)  │ (unit/int) │  staging → prod      │
└─────────┴───────────┴────────────┴──────────────────────┘
```

---

## Pipeline Definition

The pipeline YAML lives in this repository at `ci/pipeline.yaml` (managed by SMEPro, applied by LU IT):

```bash
# Log in to Concourse
fly -t lamar login -c https://concourse.lamar.edu -n iosme

# Set the pipeline
fly -t lamar set-pipeline \
  -p iosme-deploy \
  -c ci/pipeline.yaml \
  -l ci/credentials.yaml     # contains Vault/CredHub references, not secrets

# Unpause
fly -t lamar unpause-pipeline -p iosme-deploy
```

---

## Pipeline Stages

### 1. Source Trigger

The pipeline monitors the `main` branch of the IOSME application repository. Any push triggers the pipeline.

### 2. Build

```yaml
- task: build-image
  config:
    platform: linux
    image_resource:
      type: registry-image
      source: {repository: moby/buildkit}
    run:
      path: buildctl
      args:
        - build
        - --frontend=dockerfile.v0
        - --local=context=src
        - --output=type=image,name=registry.lamar.edu/iosme/app:((.:version))
```

Images are pushed to Lamar University's internal Harbor registry at `registry.lamar.edu`.

### 3. Test

- Unit tests run against the built image.
- Integration tests run against a disposable PostgreSQL instance.

### 4. Deploy to Staging

On successful test:

```bash
./scripts/deploy-iosme.sh --env staging --version ((.:version))
```

### 5. Manual Gate → Deploy to Production

A manual approval step is required before production deployment (Concourse `put: approval-gate`).

### 6. Smoke Test

Post-deploy health check:

```bash
./scripts/health-check.sh --env prod
```

---

## Credential Management

Concourse credentials are stored in **HashiCorp Vault** (or Concourse CredHub) and referenced in the pipeline as `((vault-path/key))`. No plaintext secrets in pipeline YAML.

---

## Triggering a Manual Deploy

```bash
# Trigger the deploy job manually (e.g., for a hotfix)
fly -t lamar trigger-job -j iosme-deploy/deploy-prod -w
```

---

## Monitoring Pipeline Health

The pipeline status is visible at https://concourse.lamar.edu/teams/iosme/pipelines/iosme-deploy.

Alertmanager is configured to notify `devops@lamar.edu` on pipeline failure (via Concourse Prometheus metrics).

---

## References

- [Concourse CI Documentation](https://concourse-ci.org/docs.html)
- [Helm Deployment](../helm-deployment.md)
- [scripts/deploy-iosme.sh](../../scripts/deploy-iosme.sh)

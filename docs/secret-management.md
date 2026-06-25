# Secret Management — IOSME at Lamar University

IOSME uses Kubernetes Secrets for runtime credentials. All secrets are managed through a combination of **sealed-secrets** (for GitOps-safe encryption) and manual creation for one-time bootstrap credentials.

> **Policy**: Never commit plaintext secrets to this repository. All values in this file use placeholder tokens.

---

## Secret Inventory

| Secret Name | Namespace | Purpose |
|-------------|-----------|---------|
| `iosme-db-credentials` | `iosme-prod` | PostgreSQL username / password |
| `iosme-anthropic-api-key` | `iosme-prod` | Anthropic Claude API key |
| `iosme-banner-oauth` | `iosme-prod` | Banner XE OAuth2 client credentials |
| `iosme-blackboard-lti` | `iosme-prod` | Blackboard LTI key/secret |
| `iosme-ms365-oauth` | `iosme-prod` | Microsoft 365 app client ID/secret |
| `iosme-jwt-signing-key` | `iosme-prod` | Application JWT signing key |
| `iosme-tls` | `iosme-prod` | TLS certificate for `iosme.lamar.edu` |
| `iosme-minio-credentials` | `iosme-prod` | MinIO access/secret key (file storage) |

---

## Creating Secrets

### Database Credentials

```bash
kubectl create secret generic iosme-db-credentials \
  --namespace iosme-prod \
  --from-literal=username='iosme_app' \
  --from-literal=password='<STRONG_PASSWORD>'
```

### Anthropic API Key

```bash
kubectl create secret generic iosme-anthropic-api-key \
  --namespace iosme-prod \
  --from-literal=api-key='<ANTHROPIC_API_KEY>'
```

### Banner OAuth Credentials

```bash
kubectl create secret generic iosme-banner-oauth \
  --namespace iosme-prod \
  --from-literal=client-id='<BANNER_CLIENT_ID>' \
  --from-literal=client-secret='<BANNER_CLIENT_SECRET>' \
  --from-literal=token-url='https://banner.lamar.edu/api/oauth2/token'
```

### Blackboard LTI Credentials

```bash
kubectl create secret generic iosme-blackboard-lti \
  --namespace iosme-prod \
  --from-literal=lti-key='<LTI_KEY>' \
  --from-literal=lti-secret='<LTI_SECRET>'
```

### Microsoft 365 OAuth App

```bash
kubectl create secret generic iosme-ms365-oauth \
  --namespace iosme-prod \
  --from-literal=tenant-id='<AZURE_TENANT_ID>' \
  --from-literal=client-id='<AZURE_CLIENT_ID>' \
  --from-literal=client-secret='<AZURE_CLIENT_SECRET>'
```

### JWT Signing Key

```bash
# Generate a strong random key
JWT_KEY=$(openssl rand -base64 64)
kubectl create secret generic iosme-jwt-signing-key \
  --namespace iosme-prod \
  --from-literal=signing-key="${JWT_KEY}"
```

### TLS Certificate

```bash
# Using cert-manager (recommended) — see Ingress in helm values
# Manual approach (PEM files):
kubectl create secret tls iosme-tls \
  --namespace iosme-prod \
  --cert=iosme-lamar-edu.crt \
  --key=iosme-lamar-edu.key
```

---

## Sealed Secrets (GitOps)

For GitOps workflows, encrypt secrets with **Bitnami Sealed Secrets**:

```bash
# Install kubeseal CLI
brew install kubeseal  # or download from GitHub releases

# Encrypt a secret
kubectl create secret generic iosme-db-credentials \
  --namespace iosme-prod \
  --from-literal=password='<STRONG_PASSWORD>' \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system \
           --controller-name sealed-secrets \
           --format yaml > sealed-secrets/iosme-db-credentials.yaml

# Commit the sealed secret to Git
git add sealed-secrets/iosme-db-credentials.yaml
git commit -m "chore: update iosme-db-credentials sealed secret"
```

---

## Secret Rotation Procedure

1. Generate new credential value outside Kubernetes.
2. Update the Kubernetes secret:
   ```bash
   kubectl patch secret iosme-anthropic-api-key \
     --namespace iosme-prod \
     --patch '{"data":{"api-key":"'$(echo -n "<NEW_KEY>" | base64)'"}}'
   ```
3. Perform a rolling restart to pick up the new value:
   ```bash
   kubectl rollout restart deployment/iosme-app --namespace iosme-prod
   ```
4. Update the sealed-secret YAML in this repo and commit.
5. Log the rotation in the audit log (see [Audit Chain & DR docs](audit-chain-dr.md)).

---

## References

- [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Kubernetes Secrets documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Audit Chain & DR](audit-chain-dr.md)

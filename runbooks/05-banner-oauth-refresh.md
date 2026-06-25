# Runbook 05 — Banner OAuth Refresh Failure

**Applies to**: Lamar University IOSME  
**Alert**: `BannerOAuthRefreshFailure` application event or 401/403 errors on Banner API calls  
**Scope**: Banner XE REST API OAuth2 integration  
**On-Call Level**: Level 2 (LU DevOps)  
**Estimated Time**: 15–30 minutes  

---

## Step 1 — Confirm the Failure

```bash
# Check IOSME logs for Banner auth errors
kubectl logs -l app=iosme-app -n iosme-prod --tail=200 | grep -i "banner\|oauth\|401\|403"

# Check Prometheus metrics for Banner API errors
# In Grafana: query  rate(iosme_banner_api_errors_total[5m])
```

Expected indicators:
- Log: `"banner oauth token refresh failed: 401 Unauthorized"`
- Log: `"falling back to cached enrollment data"`

---

## Step 2 — Test Banner API Manually

```bash
# Retrieve credentials from the Kubernetes secret
BANNER_TOKEN_URL=$(kubectl get secret iosme-banner-oauth -n iosme-prod \
  -o jsonpath='{.data.token-url}' | base64 --decode)
BANNER_CLIENT_ID=$(kubectl get secret iosme-banner-oauth -n iosme-prod \
  -o jsonpath='{.data.client-id}' | base64 --decode)
BANNER_CLIENT_SECRET=$(kubectl get secret iosme-banner-oauth -n iosme-prod \
  -o jsonpath='{.data.client-secret}' | base64 --decode)

# Request a token
curl -s -X POST "${BANNER_TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -u "${BANNER_CLIENT_ID}:${BANNER_CLIENT_SECRET}" | jq .
```

**Expected response**:
```json
{
  "access_token": "...",
  "token_type": "Bearer",
  "expires_in": 1800
}
```

---

## Step 3 — Diagnose Based on Error

### A: `401 Unauthorized` — Credential Problem

The client secret has likely expired or been rotated in Banner.

1. Contact the **LU Banner Admin** (banner-support@lamar.edu) to:
   - Verify the client ID is still active
   - Generate a new client secret
2. Update the Kubernetes secret:
   ```bash
   kubectl patch secret iosme-banner-oauth -n iosme-prod \
     --patch "{\"data\":{\"client-secret\":\"$(echo -n '<NEW_SECRET>' | base64)\"}}"
   ```
3. Restart the IOSME app to clear token caches:
   ```bash
   kubectl rollout restart deployment/iosme-app -n iosme-prod
   ```

### B: `503 Service Unavailable` — Banner API Outage

```bash
# Check if Banner is reachable
curl -sk https://banner.lamar.edu/api/v1/ethos/health | jq .
```

If Banner is down, contact the **LU Banner Admin team**. IOSME will serve cached enrollment data (up to 4 hours stale) automatically.

### C: Network Connectivity Issue

```bash
# Test from within the IOSME pod
kubectl exec -it deployment/iosme-app -n iosme-prod -- \
  curl -sk https://banner.lamar.edu/api/oauth2/token

# Check DNS resolution
kubectl exec -it deployment/iosme-app -n iosme-prod -- \
  nslookup banner.lamar.edu
```

If DNS or routing is failing, escalate to LU IT Networking.

### D: `429 Too Many Requests` — Rate Limit Hit

Reduce the Banner sync frequency or spread requests:

```bash
kubectl patch configmap iosme-config -n iosme-prod \
  --patch '{"data":{"BANNER_SYNC_INTERVAL_HOURS":"8"}}'
kubectl rollout restart deployment/iosme-app -n iosme-prod
```

---

## Step 4 — Verify Recovery

```bash
# Watch logs for successful Banner API calls
kubectl logs -l app=iosme-app -n iosme-prod -f | grep -i "banner"

# Look for: "banner enrollment sync completed successfully"
```

---

## Step 5 — Update Incident Log

Document the root cause, time of impact, and resolution in ITSM (ServiceNow).

---

## Escalation

| Condition | Action |
|-----------|--------|
| Banner down > 4 hours | Escalate to LU Banner Admin + LU IT |
| Credentials cannot be rotated in Banner | Escalate to LU Registrar's Office |
| Enrollment data stale > 8 hours impacting students | Notify LU Registrar's Office |

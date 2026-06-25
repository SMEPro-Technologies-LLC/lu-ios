# Runbook 07 — Anthropic API Failure

**Applies to**: Lamar University IOSME  
**Alert**: `IOSMEAnthropicAPIError` (error rate > 10%) or AI features returning errors to users  
**Scope**: Anthropic Claude API fallback for LLM features  
**On-Call Level**: Level 2 (LU DevOps)  
**Estimated Time**: 10–30 minutes  

---

## Step 1 — Confirm the Failure

```bash
# Check IOSME logs for Anthropic errors
kubectl logs -l app=iosme-app -n iosme-prod --tail=200 | grep -i "anthropic"

# Check Prometheus metric
# rate(iosme_anthropic_api_errors_total[5m]) > 0
```

Common error messages:
- `anthropic: 429 rate_limit_error`
- `anthropic: 401 authentication_error`
- `anthropic: 529 overloaded_error`
- `anthropic: connection timeout`

---

## Step 2 — Check Anthropic Status Page

Visit **https://status.anthropic.com** to check for active incidents.

```bash
# Or check from the bastion
curl -s https://status.anthropic.com/api/v2/status.json | jq '.status.description'
```

If Anthropic is reporting an outage, this is an external dependency failure. Proceed to Step 5 to enable local Ollama fallback.

---

## Step 3 — Diagnose by Error Type

### A: `401 authentication_error` — API Key Invalid

```bash
# Verify the API key is present
kubectl get secret iosme-anthropic-api-key -n iosme-prod \
  -o jsonpath='{.data.api-key}' | base64 --decode | cut -c1-10
# Should start with "sk-ant-"

# Test the key manually
ANTHROPIC_KEY=$(kubectl get secret iosme-anthropic-api-key -n iosme-prod \
  -o jsonpath='{.data.api-key}' | base64 --decode)

curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: ${ANTHROPIC_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-haiku-20240307","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' | jq .
```

If the key is invalid, request a new API key from the Anthropic console and update the secret:
```bash
kubectl patch secret iosme-anthropic-api-key -n iosme-prod \
  --patch "{\"data\":{\"api-key\":\"$(echo -n '<NEW_API_KEY>' | base64)\"}}"
kubectl rollout restart deployment/iosme-app -n iosme-prod
```

### B: `429 rate_limit_error` — Rate Limit Exceeded

Check current usage in the [Anthropic Console](https://console.anthropic.com).

Short-term fix — enable request throttling:
```bash
kubectl patch configmap iosme-config -n iosme-prod \
  --patch '{"data":{"ANTHROPIC_REQUESTS_PER_MIN":"30"}}'
kubectl rollout restart deployment/iosme-app -n iosme-prod
```

Long-term: Request a rate limit increase from Anthropic, or expand Ollama GPU capacity for local inference.

### C: `529 overloaded_error` — Anthropic API Overloaded

This is a transient Anthropic-side issue. IOSME should automatically retry with exponential backoff.

```bash
# Verify retry logic is enabled in config
kubectl get configmap iosme-config -n iosme-prod -o jsonpath='{.data.ANTHROPIC_MAX_RETRIES}'
# Expected: "3" or higher
```

Monitor and wait 5–15 minutes for Anthropic to recover.

### D: Connection Timeout

```bash
# Check DNS resolution from the pod
kubectl exec -it deployment/iosme-app -n iosme-prod -- \
  nslookup api.anthropic.com

# Check outbound connectivity (Anthropic is an external API)
kubectl exec -it deployment/iosme-app -n iosme-prod -- \
  curl -v --connect-timeout 10 https://api.anthropic.com/v1/messages
```

If DNS or routing fails, check LU firewall rules — `api.anthropic.com:443` must be allowed outbound from the `iosme-prod` namespace.

---

## Step 4 — Verify GPU Ollama is Available as Fallback

Before switching to full Ollama fallback, confirm local inference is healthy:

```bash
kubectl get pods -n iosme-prod -l app=iosme-ollama
kubectl exec -it deployment/iosme-ollama -n iosme-prod -- \
  ollama list
```

---

## Step 5 — Switch to Full Local Inference (Ollama)

If Anthropic will be unavailable for > 30 minutes:

```bash
kubectl patch configmap iosme-config -n iosme-prod \
  --patch '{"data":{"INFERENCE_PROVIDER":"ollama"}}'
kubectl rollout restart deployment/iosme-app -n iosme-prod
```

> **Note**: Local Ollama (Llama 3.2) has lower capability than Claude. Notify affected users and faculty if complex AI features are degraded.

---

## Step 6 — Restore Anthropic API

Once the issue is resolved:

```bash
kubectl patch configmap iosme-config -n iosme-prod \
  --patch '{"data":{"INFERENCE_PROVIDER":"anthropic"}}'
kubectl rollout restart deployment/iosme-app -n iosme-prod

# Verify
kubectl logs -l app=iosme-app -n iosme-prod --tail=50 | grep -i "anthropic"
```

---

## Escalation

| Condition | Action |
|-----------|--------|
| Anthropic outage > 4 hours | Notify faculty of degraded AI features; use Ollama fallback |
| API key revoked / account suspended | Escalate to SMEPro (they manage the Anthropic account) |
| Rate limits insufficient for usage | Engage SMEPro to upgrade Anthropic plan |

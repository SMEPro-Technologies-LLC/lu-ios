# Runbook 06 — LTI Launch Failure

**Applies to**: Lamar University IOSME  
**Alert**: User reports "Unable to launch IOSME from Blackboard" or 4xx/5xx errors on LTI launch  
**Scope**: Blackboard LTI 1.3 integration  
**On-Call Level**: Level 2 (LU DevOps)  
**Estimated Time**: 15–45 minutes  

---

## Step 1 — Gather Information from Affected User

Ask the user for:
- Their Blackboard username (or CWID)
- Course they are trying to launch IOSME from
- Exact error message displayed
- Browser and OS
- Screenshot if available

---

## Step 2 — Check IOSME LTI Logs

```bash
kubectl logs -l app=iosme-app -n iosme-prod --tail=300 | grep -i "lti\|launch\|jwt\|oidc"
```

Note the specific error. Common errors and their steps:

| Error | Likely Cause | Go to |
|-------|-------------|-------|
| `Invalid state parameter` | Session/cookie issue | Step 3A |
| `JWT signature verification failed` | JWKS issue | Step 3B |
| `Deployment ID not found` | Config mismatch | Step 3C |
| `iss mismatch` | Platform issuer config | Step 3D |
| `nonce reuse detected` | Clock skew / replay | Step 3E |

---

## Step 3A — Invalid State Parameter (Session/Cookie Issue)

This is usually a browser-level problem.

**User fix:**
1. Clear browser cookies and cache.
2. Disable any privacy extensions that block cookies.
3. If using Safari, disable "Prevent cross-site tracking".
4. Try in a different browser (Chrome/Firefox recommended).

**Server-side check:**
```bash
# Verify SESSION_SECRET is set correctly
kubectl get secret iosme-jwt-signing-key -n iosme-prod -o jsonpath='{.data.signing-key}' | base64 --decode | wc -c
# Should be > 32 characters
```

---

## Step 3B — JWT Signature Verification Failed

Blackboard's JWKS endpoint may have rotated keys and IOSME's cache is stale.

```bash
# Force a restart to clear JWKS cache
kubectl rollout restart deployment/iosme-app -n iosme-prod

# Verify IOSME can reach Blackboard JWKS endpoint
kubectl exec -it deployment/iosme-app -n iosme-prod -- \
  curl -sk https://blackboard.lamar.edu/api/v1/gateway/.well-known/jwks.json | jq '.keys | length'
# Should return > 0
```

---

## Step 3C — Deployment ID Not Found

The Deployment ID in the `iosme-blackboard-lti` secret doesn't match the registration in Blackboard.

```bash
# Check current deployment ID
kubectl get secret iosme-blackboard-lti -n iosme-prod \
  -o jsonpath='{.data.deployment-id}' | base64 --decode

# Compare with what Blackboard reports (requires Blackboard Admin access)
# Blackboard Admin: System Admin → LTI Tool Providers → IOSME → Deployment ID
```

If they differ, update the secret:
```bash
kubectl patch secret iosme-blackboard-lti -n iosme-prod \
  --patch "{\"data\":{\"deployment-id\":\"$(echo -n '<CORRECT_DEPLOYMENT_ID>' | base64)\"}}"
kubectl rollout restart deployment/iosme-app -n iosme-prod
```

---

## Step 3D — ISS (Issuer) Mismatch

```bash
# Check the configured platform issuer
kubectl get secret iosme-blackboard-lti -n iosme-prod \
  -o jsonpath='{.data.blackboard-platform-id}' | base64 --decode
# Expected: https://blackboard.lamar.edu

# Check what Blackboard is actually sending in JWT iss claim
# Look for it in the logs:
kubectl logs -l app=iosme-app -n iosme-prod --tail=500 | grep '"iss"'
```

Update the secret if the issuer URL changed.

---

## Step 3E — Nonce Reuse / Clock Skew

LTI 1.3 requires a fresh nonce per launch. This can fail if:
- Server clocks are out of sync (> 5 minutes)
- User reloaded or submitted the same launch twice

```bash
# Check clock sync on all nodes
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].lastHeartbeatTime}{"\n"}{end}'

# On each node
ssh ubuntu@iosme-worker-01.lamar.edu timedatectl status | grep "synchronized"
```

If clocks are out of sync, restart chrony/timesyncd:
```bash
sudo systemctl restart systemd-timesyncd
timedatectl show --property=NTPSynchronized
```

---

## Step 4 — Verify Fix

1. Ask the user to clear cookies and retry the LTI launch from Blackboard.
2. Watch logs in real time:
   ```bash
   kubectl logs -l app=iosme-app -n iosme-prod -f | grep -i "lti"
   ```
3. Look for: `"LTI launch successful"` in logs.

---

## Step 5 — Blackboard-Side Verification

If the issue persists, have a Blackboard admin check:
1. **LTI Tool Registration** is still active (not expired)
2. The tool is deployed to the correct course site
3. Blackboard event logs for the failed launch attempt

---

## Escalation

| Condition | Action |
|-----------|--------|
| Issue affects all courses / all users | Escalate to LU IT + SMEPro immediately |
| Blackboard LTI registration expired | Contact LU IT Blackboard Admin |
| LTI 1.3 protocol error requiring code fix | Escalate to SMEPro (support@smepro.com) |

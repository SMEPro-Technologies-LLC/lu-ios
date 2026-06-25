# Runbook 08 — Audit Chain Integrity

**Applies to**: Lamar University IOSME  
**Alert**: `IOSMEAuditChainIntegrity` — hash verification failure detected  
**Scope**: `iosme_audit` PostgreSQL database, audit_events table  
**On-Call Level**: Level 2 (LU DevOps) + CISO notification  
**Estimated Time**: 30–120 minutes  
**Severity**: CRITICAL — Treat as a potential security incident  

---

> ⚠️ **IMPORTANT**: An audit chain integrity failure may indicate tampering, data corruption, or a bug. Do NOT attempt to "fix" the audit data — contact the CISO immediately.

---

## Step 1 — Alert the CISO

Before any investigation, notify the LU Chief Information Security Officer (CISO):

- **Email**: ciso@lamar.edu
- **Phone**: LU IT Security on-call (see internal directory)

Include:
- Time the alert fired
- Environment (production / staging)
- Any related events in the preceding 24 hours

---

## Step 2 — Preserve Evidence

```bash
# Immediately snapshot the audit database — do NOT modify it
ssh ubuntu@iosme-db-01.lamar.edu

sudo -u postgres pg_dump -Fc iosme_audit \
  > /tmp/iosme_audit_snapshot_$(date +%Y%m%d_%H%M%S).dump

# Copy snapshot off-server to secure storage
scp iosme-db-01:/tmp/iosme_audit_snapshot_*.dump iosme-bastion:/opt/security-evidence/
```

---

## Step 3 — Run Integrity Verification

```bash
# From bastion
./scripts/backup-verify.sh --audit-chain --verbose --date $(date +%Y-%m-%d)
```

The script:
1. Reads all `audit_events` rows in `id` order
2. Recomputes `record_hash` for each row from raw fields
3. Compares computed hash to stored `record_hash`
4. Reports any mismatches with row IDs and timestamps

Sample output on failure:
```
[ERROR] Hash mismatch at audit_events.id=47382
  Stored hash:   a3f2b8c1...
  Computed hash: d9e40711...
  Event time:    2026-06-24 14:32:01 UTC
  Actor:         student:1023456
  Action:        grade.view
```

---

## Step 4 — Classify the Failure

### A: Single row mismatch — likely database corruption

```bash
# Check PostgreSQL for corruption
sudo -u postgres psql iosme_audit -c "SELECT * FROM audit_events WHERE id = <FAILED_ID>;"

# Run VACUUM and re-check
sudo -u postgres psql iosme_audit -c "VACUUM ANALYZE audit_events;"
```

If the hash mismatch is isolated to 1–2 rows and correlates with a known database event (disk error, crash), it may be corruption rather than tampering. Escalate to the CISO to decide.

### B: Sequential mismatch from row N onward — likely tampering or bulk delete

If all rows from a certain ID fail verification, rows may have been deleted or the chain was modified. This is a **security incident**:

1. Lock down database access immediately:
   ```bash
   # Revoke all connections except postgres superuser
   sudo -u postgres psql iosme_audit -c "
   REVOKE CONNECT ON DATABASE iosme_audit FROM PUBLIC;
   SELECT pg_terminate_backend(pid)
   FROM pg_stat_activity
   WHERE datname = 'iosme_audit' AND pid <> pg_backend_pid();"
   ```
2. Preserve evidence (Step 2 if not done).
3. Engage LU CISO and legal counsel.
4. Contact SMEPro to review application-level access logs.

### C: Hash mismatch in yesterday's data only — possible backup/restore issue

Check if a restore operation was performed recently:
```bash
# Check PostgreSQL activity log for recent COPY or bulk operations
sudo grep -i "audit_events" /var/lib/postgresql/15/main/log/postgresql-$(date -d yesterday +%Y-%m-%d).log
```

---

## Step 5 — Check Application Logs for Unauthorized Writes

```bash
kubectl logs -l app=iosme-app -n iosme-prod --since=24h | grep -i "audit"

# Check who has direct DB access
sudo -u postgres psql iosme_audit -c "SELECT usename, application_name, client_addr, state FROM pg_stat_activity WHERE datname='iosme_audit';"
```

---

## Step 6 — Determine if Regulatory Notification is Required

The LU CISO will determine if the audit chain breach requires:
- FERPA notification (student data)
- Notification to accrediting bodies
- Law enforcement involvement

---

## Step 7 — Resolve / Remediate

**Do NOT modify audit records** to resolve the hash mismatch. The corrupted/tampered rows must be documented and preserved.

If the failure was due to a bug in the hashing function (deploy-time regression):
1. SMEPro must provide a patch.
2. A corrected re-hash may be applied only with CISO written approval and full audit trail.
3. Deploy the fix per [Runbook 02](02-helm-deploy-upgrade-rollback.md).

---

## Step 8 — Restore Normal Operations

Once CISO has cleared the incident:

```bash
# Re-enable database access
sudo -u postgres psql iosme_audit -c "
GRANT CONNECT ON DATABASE iosme_audit TO iosme_app;"

# Clear the alert
# Run a fresh integrity check to verify clean state:
./scripts/backup-verify.sh --audit-chain --date $(date +%Y-%m-%d)
```

---

## Escalation Matrix

| Condition | Action |
|-----------|--------|
| Any integrity failure | Notify CISO within 15 minutes |
| Evidence of tampering | Treat as security incident; engage LU legal |
| Widespread data loss | Invoke DR plan per [Audit Chain & DR docs](../docs/audit-chain-dr.md) |
| Application bug caused the failure | Escalate to SMEPro, deploy patch via Runbook 02 |

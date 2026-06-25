# Audit Chain & Disaster Recovery — IOSME

This document covers IOSME's append-only audit chain and the Disaster Recovery (DR) plan for Lamar University.

---

## Audit Chain

### Purpose

IOSME maintains a cryptographically-linked audit log of all significant user actions and system events. Each audit record is chained to the previous one using a SHA-256 hash, making tampering detectable.

### Database

Audit records are stored in the `iosme_audit` PostgreSQL database on `iosme-db-01`. The audit user (`iosme_audit`) has INSERT-only privileges on the audit table — no UPDATE or DELETE.

### Audit Record Schema

```sql
CREATE TABLE audit_events (
    id            BIGSERIAL PRIMARY KEY,
    event_time    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actor_id      TEXT NOT NULL,
    actor_type    TEXT NOT NULL,        -- 'student', 'instructor', 'system'
    action        TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id   TEXT NOT NULL,
    payload       JSONB,
    previous_hash TEXT NOT NULL,
    record_hash   TEXT NOT NULL GENERATED ALWAYS AS (
                    encode(sha256(
                      (id::TEXT || event_time::TEXT || actor_id ||
                       action || resource_id || previous_hash)::bytea
                    ), 'hex')
                  ) STORED
);
```

### Integrity Verification

```bash
# Run the integrity check script (also automated nightly via cron)
./scripts/backup-verify.sh --audit-chain --date $(date +%Y-%m-%d)
```

Verification failures are alerted via `IOSMEAuditChainIntegrity` Prometheus alert (see [Observability docs](observability.md)) and escalated per [Runbook 08](../runbooks/08-audit-chain-integrity.md).

---

## Backup Strategy

### RTO and RPO Targets

| Environment | RPO | RTO |
|------------|-----|-----|
| Production | 1 hour | 4 hours |
| Staging | 24 hours | 8 hours |

### Backup Components

| Component | Method | Frequency | Retention | Destination |
|-----------|--------|-----------|-----------|-------------|
| PostgreSQL `iosme_prod` | `pg_dump` + WAL archiving | Daily dump, continuous WAL | 30 days | MinIO `iosme-backups` |
| PostgreSQL `iosme_audit` | `pg_dump` | Daily | 7 years | MinIO `iosme-audit-backups` |
| etcd (Kubernetes state) | RKE2 etcd-snapshot | Every 6 hours | 5 snapshots | MinIO `rke2-etcd` |
| Persistent Volumes | Longhorn snapshots | Daily | 7 days | Longhorn backup target |
| Helm values (secrets) | Sealed Secrets in Git | On change | Git history | This repository |

---

## Disaster Recovery Procedures

### Scenario 1: Single Node Failure

1. Kubernetes automatically reschedules pods to remaining healthy nodes.
2. Verify with `kubectl get pods -n iosme-prod -o wide`.
3. Replace failed VM per [VM Provisioning docs](vm-provisioning.md) and re-join the cluster.

### Scenario 2: Database Primary Failure

1. Promote the replica:
   ```bash
   # On iosme-db-02
   sudo -u postgres pg_ctl promote -D /var/lib/postgresql/15/main
   ```
2. Update the `iosme-db-credentials` secret's `host` to point to `iosme-db-02`.
3. Restart application pods to pick up the new DB host.
4. Rebuild the old primary as a new replica once it recovers.

Full procedure: [Runbook 03](../runbooks/03-postgres-replication-lag.md).

### Scenario 3: Full Site Failure

1. Provision new VMs on the DR vSphere cluster (or cloud equivalent).
2. Restore etcd snapshot to bootstrap Kubernetes:
   ```bash
   rke2 etcd-snapshot restore --name <SNAPSHOT_NAME>
   ```
3. Restore PostgreSQL from the latest backup:
   ```bash
   ./scripts/backup-verify.sh --restore --db iosme_prod --date <DATE>
   ```
4. Deploy the Helm chart:
   ```bash
   ./scripts/deploy-iosme.sh --env prod --version <LAST_GOOD_VERSION>
   ```
5. Update DNS to point `iosme.lamar.edu` to the new cluster.

### DR Exercise

Run quarterly DR drills using:

```bash
./scripts/dr-exercise.sh --scenario full-site --env staging
```

See the DR exercise runbook at [`scripts/dr-exercise.sh`](../scripts/dr-exercise.sh).

---

## Compliance & Retention

- Audit logs are retained for **7 years** per Lamar University records retention policy.
- Audit database backups are encrypted at rest using AES-256.
- Access to audit logs is restricted to authorized LU IT staff and external auditors.

---

## References

- [Runbook 08 — Audit Chain Integrity](../runbooks/08-audit-chain-integrity.md)
- [Database Operations](database-operations.md)
- [Observability](observability.md)

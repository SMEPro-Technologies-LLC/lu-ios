# Runbook 03 — PostgreSQL Replication Lag

**Applies to**: Lamar University IOSME  
**Alert**: `IOSMEPostgresReplicationLag` (lag > 30 seconds)  
**Scope**: PostgreSQL streaming replication between iosme-db-01 (primary) and iosme-db-02 (replica)  
**On-Call Level**: Level 2 (LU DevOps)  
**Estimated Time**: 15–45 minutes  

---

## Step 1 — Assess Current Lag

```bash
# SSH to the primary
ssh ubuntu@iosme-db-01.lamar.edu

# Check replication status
sudo -u postgres psql -c "
SELECT
  client_addr,
  state,
  (sent_lsn - replay_lsn) AS lag_bytes,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;"
```

**Thresholds**:
- < 30 s: Normal — monitor
- 30 s – 5 min: Warning — investigate
- > 5 min: Critical — consider failover

---

## Step 2 — Check Replica Status

```bash
ssh ubuntu@iosme-db-02.lamar.edu
sudo -u postgres psql -c "SELECT pg_is_in_recovery(), pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();"
```

If `pg_is_in_recovery()` returns `false`, the replica has been promoted or replication is broken.

---

## Step 3 — Check PostgreSQL Logs

```bash
# On primary
sudo journalctl -u postgresql -n 100 --no-pager | grep -iE "error|fatal|replication"

# On replica
sudo journalctl -u postgresql -n 100 --no-pager | grep -iE "error|fatal|replication"

# Check data directory
sudo -u postgres psql -c "SHOW data_directory;"
# Typically: /var/lib/postgresql/15/main
sudo tail -50 /var/lib/postgresql/15/main/log/postgresql-$(date +%Y-%m-%d).log
```

---

## Step 4 — Common Causes and Fixes

### A: Network interruption (transient)

Replication will automatically re-sync once the network is restored. Monitor and wait up to 5 minutes.

### B: Replica WAL receiver process crashed

```bash
# On replica — restart PostgreSQL
sudo systemctl restart postgresql

# Verify replication resumes
sudo -u postgres psql -c "SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();"
```

### C: WAL files purged on primary before replica caught up

```bash
# On primary — check pg_wal directory size
du -sh /var/lib/postgresql/15/main/pg_wal/

# If replica is too far behind, rebuild from base backup:
# (This will cause brief read replica outage)
ssh ubuntu@iosme-db-02.lamar.edu
sudo systemctl stop postgresql
sudo -u postgres rm -rf /var/lib/postgresql/15/main/*
sudo -u postgres pg_basebackup \
  -h iosme-db-01.lamar.edu \
  -U replicator \
  -D /var/lib/postgresql/15/main \
  -P -Xs -R
sudo systemctl start postgresql
```

### D: Disk full on replica

```bash
df -h /var/lib/postgresql/
```

If disk is >90% full, alert LU IT to expand the volume.

---

## Step 5 — Verify Recovery

```bash
# Wait 2-3 minutes, then check lag again from primary
sudo -u postgres psql -c "
SELECT client_addr, replay_lag FROM pg_stat_replication;"
```

Lag should be < 5 seconds.

---

## Step 6 — If Lag Does Not Resolve — Failover

> ⚠️ Failover is a last resort. Coordinate with LU IT and SMEPro before proceeding.

```bash
# Promote replica to primary
ssh ubuntu@iosme-db-02.lamar.edu
sudo -u postgres pg_ctl promote -D /var/lib/postgresql/15/main

# Verify it is now accepting writes
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"  # should return false

# Update the Kubernetes secret for db host
kubectl patch secret iosme-db-credentials -n iosme-prod \
  --patch '{"stringData":{"host":"iosme-db-02.lamar.edu"}}'

# Restart IOSME pods to pick up new DB host
kubectl rollout restart deployment/iosme-app -n iosme-prod
```

---

## Step 7 — Resolve Alert

Once replication lag is below 5 seconds and the Prometheus alert has resolved, add a note in the incident log (ITSM ticket).

---

## Escalation

| Condition | Action |
|-----------|--------|
| Both DB nodes unreachable | Escalate to LU IT infrastructure team |
| Data corruption suspected | Escalate immediately to SMEPro (support@smepro.com) and LU IT |
| Failover required during business hours | Notify LU Registrar's Office of brief disruption |

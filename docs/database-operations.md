# Database Operations — PostgreSQL for IOSME

IOSME uses **PostgreSQL 15** in a primary/replica streaming replication configuration.

---

## Database Topology

| Host | Role | Port | Replica Source |
|------|------|------|----------------|
| iosme-db-01.lamar.edu | Primary (read-write) | 5432 | — |
| iosme-db-02.lamar.edu | Replica (read-only) | 5432 | iosme-db-01 |

The application connects to the primary for writes and may use the replica for read-heavy reporting queries.

---

## Database Names

| Database | Owner | Purpose |
|----------|-------|---------|
| `iosme_prod` | `iosme_app` | Production application data |
| `iosme_audit` | `iosme_audit` | Append-only audit chain (see [Audit Chain docs](audit-chain-dr.md)) |

---

## Initial Setup

### Install PostgreSQL 15

```bash
# On iosme-db-01 and iosme-db-02
apt-get install -y postgresql-15 postgresql-client-15

systemctl enable postgresql
systemctl start postgresql
```

### Create Application Database and User

```bash
sudo -u postgres psql <<EOF
CREATE USER iosme_app WITH PASSWORD '<STRONG_PASSWORD>';
CREATE DATABASE iosme_prod OWNER iosme_app;
GRANT ALL PRIVILEGES ON DATABASE iosme_prod TO iosme_app;

CREATE USER iosme_audit WITH PASSWORD '<AUDIT_PASSWORD>';
CREATE DATABASE iosme_audit OWNER iosme_audit;

-- Read-only replica user for reporting
CREATE USER iosme_reader WITH PASSWORD '<READER_PASSWORD>';
GRANT CONNECT ON DATABASE iosme_prod TO iosme_reader;
GRANT USAGE ON SCHEMA public TO iosme_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO iosme_reader;
EOF
```

---

## Streaming Replication Setup

### Primary (iosme-db-01)

```bash
# /etc/postgresql/15/main/postgresql.conf
wal_level = replica
max_wal_senders = 5
wal_keep_size = 1GB
listen_addresses = '*'

# /etc/postgresql/15/main/pg_hba.conf — add:
# host  replication  replicator  iosme-db-02/32  scram-sha-256
```

```bash
sudo -u postgres psql -c "CREATE USER replicator REPLICATION LOGIN PASSWORD '<REPL_PASSWORD>';"
systemctl reload postgresql
```

### Replica (iosme-db-02)

```bash
systemctl stop postgresql
rm -rf /var/lib/postgresql/15/main/*

sudo -u postgres pg_basebackup \
  -h iosme-db-01.lamar.edu \
  -U replicator \
  -D /var/lib/postgresql/15/main \
  -P -Xs -R

systemctl start postgresql
```

---

## Monitoring Replication Lag

```sql
-- Run on primary
SELECT
  client_addr,
  state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  (sent_lsn - replay_lsn) AS replication_lag_bytes,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;
```

Alert threshold: **replication lag > 30 seconds** → page on-call (see [Runbook 03](../runbooks/03-postgres-replication-lag.md)).

---

## Backup Procedures

### Continuous WAL Archiving

```bash
# /etc/postgresql/15/main/postgresql.conf
archive_mode = on
archive_command = 'test ! -f /mnt/wal-archive/%f && cp %p /mnt/wal-archive/%f'
```

### Daily pg_dump Backup

Managed by a cron job on iosme-db-01:

```bash
# /etc/cron.d/iosme-pg-backup
0 2 * * * postgres /usr/local/bin/iosme-pg-backup.sh
```

### Backup Verification

```bash
./scripts/backup-verify.sh --db iosme_prod --date $(date +%Y-%m-%d)
```

---

## Common Maintenance Tasks

### Vacuuming

```sql
-- Manual vacuum analyze (schedule during low-traffic windows)
VACUUM ANALYZE iosme_prod.public.sessions;
```

### Connection Pooling

IOSME uses **PgBouncer** in transaction mode. PgBouncer runs on both database nodes and is managed by the Helm chart.

```
max_client_conn = 500
default_pool_size = 25
pool_mode = transaction
```

---

## References

- [Runbook 03 — Postgres Replication Lag](../runbooks/03-postgres-replication-lag.md)
- [Audit Chain & DR](audit-chain-dr.md)
- [PostgreSQL 15 Documentation](https://www.postgresql.org/docs/15/)

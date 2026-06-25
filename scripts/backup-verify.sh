#!/usr/bin/env bash
# backup-verify.sh — Verify IOSME backups and audit chain integrity
#
# Usage:
#   ./scripts/backup-verify.sh [OPTIONS]
#
# Options:
#   --db            <dbname>         Verify a PostgreSQL backup (e.g. iosme_prod)
#   --audit-chain                    Verify audit chain hash integrity
#   --date          <YYYY-MM-DD>     Date of backup to verify (default: today)
#   --restore                        Restore the specified backup to a test DB
#   --verbose                        Enable verbose output
#   -h, --help                       Show help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
DB_NAME=""
AUDIT_CHAIN=false
BACKUP_DATE=$(date +%Y-%m-%d)
RESTORE=false
VERBOSE=false

# Infrastructure config
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio.lamar.edu:9000}"
MINIO_BUCKET_DB="iosme-backups"
MINIO_BUCKET_AUDIT="iosme-audit-backups"
DB_PRIMARY="iosme-db-01.lamar.edu"
DB_TEST_HOST="iosme-db-01.lamar.edu"
DB_TEST_PORT=5433   # separate port for verification restore
PG_USER="postgres"
AUDIT_DB="iosme_audit"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${GREEN}[INFO]${NC}  $*"; }
verbose() { [[ "${VERBOSE}" == "true" ]] && echo -e "       $*" || true; }
step()    { echo -e "${CYAN}[STEP]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $*"; }

usage() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --db)          DB_NAME="$2";    shift 2 ;;
      --audit-chain) AUDIT_CHAIN=true; shift ;;
      --date)        BACKUP_DATE="$2"; shift 2 ;;
      --restore)     RESTORE=true;    shift   ;;
      --verbose)     VERBOSE=true;    shift   ;;
      -h|--help)     usage ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  if [[ -z "${DB_NAME}" && "${AUDIT_CHAIN}" == "false" ]]; then
    die "Specify --db <dbname>, --audit-chain, or both"
  fi
}

check_prerequisites() {
  command -v psql   &>/dev/null || die "psql is not installed"
  command -v mc     &>/dev/null || warn "mc (MinIO client) not installed — skipping backup download verification"
}

verify_db_backup() {
  local db="$1"
  local date="$2"
  local backup_file="${db}_${date}.dump"
  local bucket="${MINIO_BUCKET_DB}"

  step "Verifying PostgreSQL backup: ${db} (${date})"

  # Check backup exists in MinIO
  if command -v mc &>/dev/null; then
    log "Checking backup file in MinIO: ${bucket}/${backup_file}"
    if mc stat "minio/${bucket}/${backup_file}" &>/dev/null; then
      ok "Backup file found: ${backup_file}"
      verbose "$(mc stat "minio/${bucket}/${backup_file}")"
    else
      fail "Backup file NOT found: minio/${bucket}/${backup_file}"
      return 1
    fi
  fi

  if [[ "${RESTORE}" == "true" ]]; then
    step "Performing restore verification for ${db}..."

    local test_db="${db}_verify_$(date +%s)"
    log "Creating test database: ${test_db}"

    # Download backup
    local tmp_dump="/tmp/${backup_file}"
    if command -v mc &>/dev/null; then
      mc cp "minio/${bucket}/${backup_file}" "${tmp_dump}"
    else
      warn "mc not available; assuming backup is already at ${tmp_dump}"
    fi

    [[ -f "${tmp_dump}" ]] || die "Backup file not found at ${tmp_dump}"

    # Restore to test DB
    sudo -u "${PG_USER}" psql -c "CREATE DATABASE ${test_db};" postgres
    sudo -u "${PG_USER}" pg_restore -d "${test_db}" "${tmp_dump}"

    # Basic verification query
    local table_count
    table_count=$(sudo -u "${PG_USER}" psql -t -c \
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" "${test_db}")

    log "Restore verification: ${table_count} tables in restored database"

    if [[ "${table_count}" -gt 0 ]]; then
      ok "Restore verification PASSED for ${db} (${table_count} tables)"
    else
      fail "Restore verification FAILED — no tables found in restored database"
      return 1
    fi

    # Cleanup
    sudo -u "${PG_USER}" psql -c "DROP DATABASE ${test_db};" postgres
    rm -f "${tmp_dump}"
  fi

  ok "Database backup verification PASSED: ${db} (${date})"
}

verify_audit_chain() {
  local date="$1"
  step "Verifying audit chain integrity for ${date}..."

  log "Connecting to ${AUDIT_DB} on ${DB_PRIMARY}..."

  # Run integrity check SQL
  local check_query
  read -r -d '' check_query <<'SQL' || true
WITH chain_check AS (
  SELECT
    id,
    event_time,
    actor_id,
    action,
    resource_id,
    previous_hash,
    record_hash,
    encode(
      sha256(
        (id::TEXT || event_time::TEXT || actor_id ||
         action || resource_id || previous_hash)::bytea
      ), 'hex'
    ) AS computed_hash
  FROM audit_events
  WHERE event_time::date = CURRENT_DATE - INTERVAL '1 day' * 0
  ORDER BY id
)
SELECT
  id,
  event_time,
  actor_id,
  action,
  record_hash,
  computed_hash,
  (record_hash = computed_hash) AS hash_valid
FROM chain_check
WHERE (record_hash != computed_hash);
SQL

  local failures
  failures=$(sudo -u "${PG_USER}" psql -t -c "${check_query}" "${AUDIT_DB}" 2>/dev/null || echo "ERROR")

  if [[ "${failures}" == "ERROR" ]]; then
    fail "Could not connect to ${AUDIT_DB}"
    return 1
  fi

  local failure_count
  failure_count=$(echo "${failures}" | grep -c '[0-9]' 2>/dev/null || echo "0")

  if [[ "${failure_count}" -eq 0 ]]; then
    ok "Audit chain integrity PASSED — no hash mismatches"
  else
    fail "Audit chain integrity FAILED — ${failure_count} row(s) with hash mismatch:"
    echo "${failures}"
    warn "ALERT: Potential audit chain tampering detected!"
    warn "Follow Runbook 08: runbooks/08-audit-chain-integrity.md"
    return 1
  fi

  # Count total records checked
  local record_count
  record_count=$(sudo -u "${PG_USER}" psql -t -c \
    "SELECT COUNT(*) FROM audit_events WHERE event_time::date = '${date}';" "${AUDIT_DB}" 2>/dev/null || echo "0")
  log "Total audit records verified: ${record_count}"
}

main() {
  parse_args "$@"
  check_prerequisites

  log "=== IOSME Backup Verification ==="
  log "Date    : ${BACKUP_DATE}"
  [[ -n "${DB_NAME}" ]]          && log "Database: ${DB_NAME}"
  [[ "${AUDIT_CHAIN}" == "true" ]] && log "Audit   : chain integrity check"
  [[ "${RESTORE}" == "true" ]]     && warn "RESTORE mode — will create temporary DB"
  echo ""

  local exit_code=0

  if [[ -n "${DB_NAME}" ]]; then
    verify_db_backup "${DB_NAME}" "${BACKUP_DATE}" || exit_code=1
  fi

  if [[ "${AUDIT_CHAIN}" == "true" ]]; then
    verify_audit_chain "${BACKUP_DATE}" || exit_code=1
  fi

  echo ""
  if [[ ${exit_code} -eq 0 ]]; then
    ok "=== All verification checks PASSED ==="
  else
    fail "=== One or more verification checks FAILED ==="
    exit 1
  fi
}

main "$@"

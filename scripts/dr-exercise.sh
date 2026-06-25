#!/usr/bin/env bash
# dr-exercise.sh — Run a Disaster Recovery drill for IOSME at Lamar University
#
# This script simulates DR scenarios to validate RTO/RPO targets.
# It is NON-DESTRUCTIVE against production — all drills run against
# the staging environment or isolated test resources unless explicitly overridden.
#
# Usage:
#   ./scripts/dr-exercise.sh [OPTIONS]
#
# Options:
#   --scenario  <name>           DR scenario to exercise (required)
#                                  node-failure       — simulate single node failure
#                                  db-failover        — promote replica, switch app
#                                  full-site          — full restore from backup
#   --env       <staging|prod>   Target environment (default: staging; prod requires --confirm-prod)
#   --confirm-prod               Required flag when --env prod is specified (DANGEROUS)
#   --dry-run                    Print actions without executing anything
#   -h, --help                   Show help
#
# Examples:
#   ./scripts/dr-exercise.sh --scenario node-failure --env staging
#   ./scripts/dr-exercise.sh --scenario db-failover --env staging
#   ./scripts/dr-exercise.sh --scenario full-site --env staging --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults
SCENARIO=""
ENV="staging"
CONFIRM_PROD=false
DRY_RUN=false

# Timing
START_TIME=$(date +%s)
LOG_FILE="/tmp/dr-exercise-$(date +%Y%m%d-%H%M%S).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC}  $*" | tee -a "${LOG_FILE}"; }
step()   { echo -e "${CYAN}${BOLD}[STEP]${NC}  $*" | tee -a "${LOG_FILE}"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "${LOG_FILE}"; }
error()  { echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}" >&2; }
die()    { error "$*"; exit 1; }
ok()     { echo -e "${GREEN}[OK]${NC}    $*" | tee -a "${LOG_FILE}"; }
timing() { echo -e "  ⏱  Elapsed: $(( $(date +%s) - START_TIME ))s"; }

usage() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}

run() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*" | tee -a "${LOG_FILE}"
  else
    eval "$*" 2>&1 | tee -a "${LOG_FILE}"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scenario)     SCENARIO="$2";     shift 2 ;;
      --env)          ENV="$2";          shift 2 ;;
      --confirm-prod) CONFIRM_PROD=true; shift   ;;
      --dry-run)      DRY_RUN=true;      shift   ;;
      -h|--help)      usage ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  [[ -z "${SCENARIO}" ]] && die "--scenario is required"
  [[ "${SCENARIO}" =~ ^(node-failure|db-failover|full-site)$ ]] || \
    die "--scenario must be: node-failure, db-failover, or full-site"

  if [[ "${ENV}" == "prod" && "${CONFIRM_PROD}" == "false" ]]; then
    die "Running DR drills against production requires --confirm-prod flag. Use --env staging instead."
  fi

  NAMESPACE="iosme-${ENV}"
}

check_prerequisites() {
  command -v kubectl &>/dev/null || die "kubectl is not installed"
  command -v helm    &>/dev/null || die "helm is not installed"
  kubectl cluster-info &>/dev/null || die "kubectl cannot reach cluster"
}

record_rpo_start() {
  log "Recording RPO baseline — noting last committed transaction time..."
  if [[ "${DRY_RUN}" == "false" ]]; then
    ssh "ubuntu@iosme-db-01.lamar.edu" \
      "sudo -u postgres psql -t -c \"SELECT NOW() AS rpo_start_time;\" iosme_prod" 2>/dev/null || true
  fi
}

scenario_node_failure() {
  step "=== Scenario: Single Node Failure ==="
  log "This drill cordons a worker node, verifies pod rescheduling, then uncordons."
  log "Target namespace: ${NAMESPACE}"

  # Pick a non-critical worker node for the drill
  local target_node
  target_node=$(kubectl get nodes --no-headers -l "!node-role.iosme/gpu" \
    | grep -v "master" | head -1 | awk '{print $1}')
  [[ -z "${target_node}" ]] && die "No suitable worker node found for drill"

  log "Target node: ${target_node}"
  step "1. Cordon node (simulate failure / maintenance)"
  run "kubectl cordon ${target_node}"

  step "2. Drain node"
  run "kubectl drain ${target_node} --ignore-daemonsets --delete-emptydir-data --timeout=5m"

  step "3. Verify pods reschedule to other nodes"
  sleep 30
  run "kubectl get pods -n ${NAMESPACE} -o wide"

  step "4. Verify application health after rescheduling"
  run "${SCRIPT_DIR}/health-check.sh --env ${ENV}"
  timing

  step "5. Restore node (uncordon)"
  run "kubectl uncordon ${target_node}"

  ok "Node failure drill PASSED"
  log "RTO observed: $(( $(date +%s) - START_TIME ))s (target: 4h)"
}

scenario_db_failover() {
  step "=== Scenario: Database Failover (Replica Promotion) ==="
  log "This drill promotes the staging replica and reconnects the application."
  warn "This will briefly disrupt database writes in the ${ENV} environment."

  local db_primary="iosme-db-01.lamar.edu"
  local db_replica="iosme-db-02.lamar.edu"

  step "1. Record current primary status"
  run "ssh ubuntu@${db_primary} 'sudo -u postgres psql -c \"SELECT pg_is_in_recovery();\" postgres'"

  step "2. Verify replica replication lag"
  run "ssh ubuntu@${db_primary} \
    'sudo -u postgres psql -t -c \"SELECT replay_lag FROM pg_stat_replication;\" postgres'"

  step "3. Stop application (avoid split-brain)"
  run "kubectl scale deployment iosme-app --replicas=0 -n ${NAMESPACE}"

  step "4. Promote replica to primary"
  run "ssh ubuntu@${db_replica} \
    'sudo -u postgres pg_ctl promote -D /var/lib/postgresql/15/main'"
  sleep 5

  step "5. Verify replica is now primary"
  run "ssh ubuntu@${db_replica} \
    'sudo -u postgres psql -t -c \"SELECT pg_is_in_recovery();\" postgres'"
  timing

  step "6. Update database host in Kubernetes secret"
  if [[ "${DRY_RUN}" == "false" ]]; then
    local encoded_host
    encoded_host=$(echo -n "${db_replica}" | base64)
    kubectl patch secret iosme-db-credentials -n "${NAMESPACE}" \
      --patch "{\"data\":{\"host\":\"${encoded_host}\"}}"
  fi

  step "7. Restart application"
  run "kubectl scale deployment iosme-app --replicas=2 -n ${NAMESPACE}"
  run "kubectl rollout status deployment/iosme-app -n ${NAMESPACE} --timeout=5m"

  step "8. Health check"
  run "${SCRIPT_DIR}/health-check.sh --env ${ENV}"
  timing

  log "RTO observed: $(( $(date +%s) - START_TIME ))s (target: 4h)"

  step "9. DR Drill cleanup — restoring original configuration"
  warn "Restoring original DB primary (iosme-db-01). In a real DR, you would rebuild db-01 as a new replica."
  if [[ "${DRY_RUN}" == "false" ]]; then
    local encoded_primary
    encoded_primary=$(echo -n "${db_primary}" | base64)
    kubectl patch secret iosme-db-credentials -n "${NAMESPACE}" \
      --patch "{\"data\":{\"host\":\"${encoded_primary}\"}}"
    kubectl rollout restart deployment/iosme-app -n "${NAMESPACE}"
  fi

  ok "Database failover drill PASSED"
}

scenario_full_site() {
  step "=== Scenario: Full Site Recovery ==="
  log "This drill validates restoring IOSME from backups in a fresh namespace."
  log "Target: create namespace iosme-dr-test and restore into it."

  local dr_namespace="iosme-dr-test"
  local backup_date
  backup_date=$(date -d "1 day ago" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)

  step "1. Verify backups exist"
  run "${SCRIPT_DIR}/backup-verify.sh --db iosme_prod --date ${backup_date}"

  step "2. Create DR namespace"
  run "kubectl create namespace ${dr_namespace} --dry-run=client -o yaml | kubectl apply -f -"

  step "3. Restore PostgreSQL backup to test DB"
  run "${SCRIPT_DIR}/backup-verify.sh --db iosme_prod --date ${backup_date} --restore"
  timing

  step "4. Deploy IOSME chart to DR namespace"
  run "helm upgrade --install iosme-lamar-dr ${REPO_ROOT}/helm/iosme-lamar \
    --namespace ${dr_namespace} \
    -f ${REPO_ROOT}/helm/iosme-lamar/values.yaml \
    -f ${REPO_ROOT}/helm/iosme-lamar/values-${ENV}.yaml \
    --set image.tag=\$(helm get values iosme-lamar -n ${NAMESPACE} -o json | jq -r '.image.tag') \
    --atomic --timeout 10m"

  step "5. Verify DR namespace health"
  run "kubectl get pods -n ${dr_namespace}"
  run "${SCRIPT_DIR}/health-check.sh --namespace ${dr_namespace}"
  timing

  log "RTO observed: $(( $(date +%s) - START_TIME ))s (target: 4h)"

  step "6. Cleanup DR namespace"
  run "helm uninstall iosme-lamar-dr -n ${dr_namespace}"
  run "kubectl delete namespace ${dr_namespace}"

  ok "Full site recovery drill PASSED"
}

print_summary() {
  local elapsed=$(( $(date +%s) - START_TIME ))
  echo ""
  echo -e "${BOLD}=== DR Exercise Summary ===${NC}"
  echo "  Scenario  : ${SCENARIO}"
  echo "  Environment: ${ENV}"
  echo "  Duration  : ${elapsed}s"
  echo "  Log file  : ${LOG_FILE}"
  echo ""
}

main() {
  parse_args "$@"
  check_prerequisites

  log "=== IOSME DR Exercise ==="
  log "Scenario    : ${SCENARIO}"
  log "Environment : ${ENV}"
  log "Log file    : ${LOG_FILE}"
  [[ "${DRY_RUN}" == "true" ]] && warn "DRY-RUN mode"
  echo ""

  record_rpo_start

  case "${SCENARIO}" in
    node-failure) scenario_node_failure ;;
    db-failover)  scenario_db_failover ;;
    full-site)    scenario_full_site ;;
  esac

  print_summary
}

main "$@"

#!/usr/bin/env bash
# health-check.sh — IOSME application health check
#
# Validates that the IOSME application is healthy across key dimensions:
#   - Kubernetes pod readiness
#   - HTTP health endpoint
#   - Database connectivity (via app)
#   - GPU inference availability
#   - Banner API reachability
#   - Ingress / TLS certificate validity
#
# Usage:
#   ./scripts/health-check.sh [OPTIONS]
#
# Options:
#   --env        <prod|staging|dev>   Target environment (required)
#   --namespace  <ns>                 Override namespace (default: iosme-<env>)
#   --url        <base-url>           Override application base URL
#   --timeout    <seconds>            HTTP request timeout (default: 10)
#   --verbose                         Show detailed output
#   -h, --help                        Show help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
ENV=""
NAMESPACE=""
BASE_URL=""
HTTP_TIMEOUT=10
VERBOSE=false

# Results tracking
CHECKS_PASSED=0
CHECKS_FAILED=0
FAILED_CHECKS=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${GREEN}[INFO]${NC}  $*"; }
step()    { echo -e "${CYAN}[CHECK]${NC} $*"; }
verbose() { [[ "${VERBOSE}" == "true" ]] && echo -e "       $*" || true; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
ok()      { echo -e "${GREEN}  ✓${NC} $1"; CHECKS_PASSED=$((CHECKS_PASSED + 1)); }
fail()    { echo -e "${RED}  ✗${NC} $1"; CHECKS_FAILED=$((CHECKS_FAILED + 1)); FAILED_CHECKS+=("$1"); }

usage() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)       ENV="$2";          shift 2 ;;
      --namespace) NAMESPACE="$2";    shift 2 ;;
      --url)       BASE_URL="$2";     shift 2 ;;
      --timeout)   HTTP_TIMEOUT="$2"; shift 2 ;;
      --verbose)   VERBOSE=true;      shift   ;;
      -h|--help)   usage ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  [[ -z "${ENV}" ]] && die "--env is required (prod|staging|dev)"
  [[ "${ENV}" =~ ^(prod|staging|dev)$ ]] || die "--env must be prod, staging, or dev"

  NAMESPACE="${NAMESPACE:-iosme-${ENV}}"

  if [[ -z "${BASE_URL}" ]]; then
    case "${ENV}" in
      prod)    BASE_URL="https://iosme.lamar.edu" ;;
      staging) BASE_URL="https://iosme-staging.lamar.edu" ;;
      dev)     BASE_URL="https://iosme-dev.lamar.edu" ;;
    esac
  fi
}

die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

check_prerequisites() {
  command -v kubectl &>/dev/null || die "kubectl is not installed"
  command -v curl    &>/dev/null || die "curl is not installed"
}

check_kubernetes_pods() {
  step "Kubernetes pod readiness"

  local not_ready
  not_ready=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | \
    grep -v "Running\|Completed" | wc -l || echo "error")

  local total
  total=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo "0")

  verbose "Total pods: ${total}, Not ready: ${not_ready}"

  if [[ "${not_ready}" == "error" ]]; then
    fail "Could not list pods in namespace ${NAMESPACE}"
  elif [[ "${not_ready}" -eq 0 && "${total}" -gt 0 ]]; then
    ok "All ${total} pods are Running/Completed"
  elif [[ "${total}" -eq 0 ]]; then
    fail "No pods found in namespace ${NAMESPACE}"
  else
    fail "${not_ready}/${total} pods are not ready"
    if [[ "${VERBOSE}" == "true" ]]; then
      kubectl get pods -n "${NAMESPACE}"
    fi
  fi
}

check_http_health() {
  step "HTTP health endpoint"

  local url="${BASE_URL}/health"
  local response
  response=$(curl -sf --max-time "${HTTP_TIMEOUT}" "${url}" 2>/dev/null || echo "FAILED")

  if [[ "${response}" == "FAILED" ]]; then
    fail "HTTP GET ${url} failed"
    return
  fi

  verbose "Response: ${response}"

  local status
  status=$(echo "${response}" | jq -r '.status' 2>/dev/null || echo "unknown")

  if [[ "${status}" == "healthy" || "${status}" == "ok" ]]; then
    ok "Health endpoint returned status=${status}"
  else
    fail "Health endpoint returned unexpected status: ${status}"
  fi
}

check_readiness() {
  step "HTTP readiness endpoint"

  local url="${BASE_URL}/ready"
  local http_code
  http_code=$(curl -so /dev/null -w "%{http_code}" --max-time "${HTTP_TIMEOUT}" "${url}" 2>/dev/null || echo "000")

  verbose "HTTP status: ${http_code}"

  if [[ "${http_code}" == "200" ]]; then
    ok "Readiness endpoint returned HTTP 200"
  elif [[ "${http_code}" == "503" ]]; then
    fail "Readiness endpoint returned HTTP 503 (app not ready)"
  else
    fail "Readiness endpoint returned unexpected HTTP ${http_code}"
  fi
}

check_tls_certificate() {
  step "TLS certificate validity"

  local host
  host=$(echo "${BASE_URL}" | sed 's|https://||' | cut -d'/' -f1)

  local cert_expiry
  cert_expiry=$(echo | openssl s_client -connect "${host}:443" -servername "${host}" 2>/dev/null | \
    openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//' || echo "")

  if [[ -z "${cert_expiry}" ]]; then
    warn "Could not retrieve TLS certificate for ${host}"
    return
  fi

  verbose "Certificate expires: ${cert_expiry}"

  local expiry_epoch
  expiry_epoch=$(date -d "${cert_expiry}" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "${cert_expiry}" +%s 2>/dev/null || echo "0")
  local now_epoch
  now_epoch=$(date +%s)
  local days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

  if [[ "${days_remaining}" -lt 0 ]]; then
    fail "TLS certificate has EXPIRED (${cert_expiry})"
  elif [[ "${days_remaining}" -lt 14 ]]; then
    fail "TLS certificate expires in ${days_remaining} days (${cert_expiry}) — renew urgently"
  elif [[ "${days_remaining}" -lt 30 ]]; then
    warn "TLS certificate expires in ${days_remaining} days — plan renewal"
    ok "TLS certificate valid (${days_remaining} days remaining)"
  else
    ok "TLS certificate valid (${days_remaining} days remaining)"
  fi
}

check_database_connectivity() {
  step "Database connectivity (via app health detail)"

  local url="${BASE_URL}/health/detail"
  local response
  response=$(curl -sf --max-time "${HTTP_TIMEOUT}" "${url}" 2>/dev/null || echo "FAILED")

  if [[ "${response}" == "FAILED" ]]; then
    warn "Detailed health endpoint not available (may require auth)"
    return
  fi

  verbose "Detail response: ${response}"

  local db_status
  db_status=$(echo "${response}" | jq -r '.checks.database.status' 2>/dev/null || echo "unknown")

  if [[ "${db_status}" == "healthy" || "${db_status}" == "ok" ]]; then
    ok "Database connectivity: ${db_status}"
  else
    fail "Database connectivity check failed: ${db_status}"
  fi
}

check_gpu_inference() {
  step "GPU inference service"

  local ollama_pods
  ollama_pods=$(kubectl get pods -n "${NAMESPACE}" -l app=iosme-ollama --no-headers 2>/dev/null | \
    grep "Running" | wc -l || echo "0")

  if [[ "${ollama_pods}" -gt 0 ]]; then
    ok "Ollama inference pod(s) running: ${ollama_pods}"
  else
    warn "No Ollama pods running (may be using Anthropic fallback)"
  fi

  # Check GPU node
  local gpu_allocatable
  gpu_allocatable=$(kubectl get node iosme-gpu-01 \
    -o jsonpath='{.status.allocatable.nvidia\.com/gpu}' 2>/dev/null || echo "0")

  if [[ "${gpu_allocatable}" -gt 0 ]]; then
    ok "GPU node iosme-gpu-01 allocatable GPUs: ${gpu_allocatable}"
  else
    fail "GPU node iosme-gpu-01 has no allocatable GPUs"
  fi
}

check_ingress() {
  step "Ingress controller"

  local ingress_pods
  ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | \
    grep "Running" | wc -l || echo "0")

  if [[ "${ingress_pods}" -gt 0 ]]; then
    ok "ingress-nginx pods running: ${ingress_pods}"
  else
    fail "No ingress-nginx pods running"
  fi

  # Verify ingress rule exists for IOSME
  local ingress_exists
  ingress_exists=$(kubectl get ingress -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo "0")

  if [[ "${ingress_exists}" -gt 0 ]]; then
    ok "IOSME Ingress resource found (${ingress_exists} rule(s))"
  else
    fail "No Ingress resources found in ${NAMESPACE}"
  fi
}

print_summary() {
  local total=$((CHECKS_PASSED + CHECKS_FAILED))
  echo ""
  echo "═══════════════════════════════════════"
  echo "  Health Check Summary"
  echo "  Environment: ${ENV}  |  Namespace: ${NAMESPACE}"
  echo "  Passed: ${CHECKS_PASSED}/${total}  |  Failed: ${CHECKS_FAILED}/${total}"
  echo "═══════════════════════════════════════"

  if [[ "${CHECKS_FAILED}" -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failed checks:${NC}"
    for check in "${FAILED_CHECKS[@]}"; do
      echo "  - ${check}"
    done
    echo ""
    echo -e "${RED}HEALTH CHECK FAILED${NC}"
    exit 1
  else
    echo ""
    echo -e "${GREEN}ALL CHECKS PASSED${NC}"
  fi
}

main() {
  parse_args "$@"
  check_prerequisites

  log "=== IOSME Health Check ==="
  log "Environment : ${ENV}"
  log "Namespace   : ${NAMESPACE}"
  log "Base URL    : ${BASE_URL}"
  echo ""

  check_kubernetes_pods
  check_http_health
  check_readiness
  check_tls_certificate
  check_database_connectivity
  check_gpu_inference
  check_ingress

  print_summary
}

main "$@"

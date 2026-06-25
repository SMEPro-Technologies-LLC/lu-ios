#!/usr/bin/env bash
# deploy-iosme.sh — Deploy or rollback the IOSME Helm chart
#
# Usage:
#   ./scripts/deploy-iosme.sh [OPTIONS]
#
# Options:
#   --env       <prod|staging|dev>   Target environment (required)
#   --version   <image-tag>          Image tag to deploy (required unless --rollback)
#   --rollback                       Roll back to the previous Helm revision
#   --revision  <n>                  Roll back to a specific Helm revision
#   --namespace <ns>                 Override default namespace
#   --timeout   <duration>           Helm timeout (default: 10m)
#   --dry-run                        Pass --dry-run to Helm (template output only)
#   --skip-health-check              Skip post-deploy health check
#   -h, --help                       Show help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HELM_CHART="${REPO_ROOT}/helm/iosme-lamar"
HEALTH_CHECK="${SCRIPT_DIR}/health-check.sh"

# Defaults
ENV=""
IMAGE_TAG=""
ROLLBACK=false
REVISION=""
TIMEOUT="10m"
DRY_RUN=false
SKIP_HEALTH_CHECK=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${GREEN}[INFO]${NC}  $*"; }
step()    { echo -e "${CYAN}[STEP]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

usage() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)                ENV="$2";       shift 2 ;;
      --version)            IMAGE_TAG="$2"; shift 2 ;;
      --rollback)           ROLLBACK=true;  shift   ;;
      --revision)           REVISION="$2";  shift 2 ;;
      --namespace)          NAMESPACE="$2"; shift 2 ;;
      --timeout)            TIMEOUT="$2";   shift 2 ;;
      --dry-run)            DRY_RUN=true;   shift   ;;
      --skip-health-check)  SKIP_HEALTH_CHECK=true; shift ;;
      -h|--help)            usage ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  [[ -z "${ENV}" ]] && die "--env is required (prod|staging|dev)"
  [[ "${ENV}" =~ ^(prod|staging|dev)$ ]] || die "--env must be prod, staging, or dev"

  if [[ "${ROLLBACK}" == "false" && -z "${IMAGE_TAG}" ]]; then
    die "--version is required (or use --rollback)"
  fi

  # Derive namespace from env unless overridden
  NAMESPACE="${NAMESPACE:-iosme-${ENV}}"
}

check_prerequisites() {
  command -v helm    &>/dev/null || die "helm is not installed"
  command -v kubectl &>/dev/null || die "kubectl is not installed"

  [[ -d "${HELM_CHART}" ]] || die "Helm chart not found at ${HELM_CHART}"

  # Verify kubectl can reach the cluster
  kubectl cluster-info &>/dev/null || die "kubectl cannot reach the cluster (check KUBECONFIG)"
}

pre_deploy_checks() {
  step "Pre-deployment checks..."

  # Check cluster node health
  local not_ready
  not_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -v "Ready" | wc -l)
  if [[ "${not_ready}" -gt 0 ]]; then
    warn "${not_ready} node(s) are not Ready. Review before proceeding:"
    kubectl get nodes
  fi

  # Show current release
  log "Current Helm release status:"
  helm status "iosme-lamar" --namespace "${NAMESPACE}" 2>/dev/null || \
    log "  (no existing release found)"

  log "Helm release history:"
  helm history "iosme-lamar" --namespace "${NAMESPACE}" --max 5 2>/dev/null || true
}

do_deploy() {
  step "Deploying iosme-lamar version=${IMAGE_TAG} to namespace=${NAMESPACE}..."

  local values_base="${HELM_CHART}/values.yaml"
  local values_env="${HELM_CHART}/values-${ENV}.yaml"
  local dry_run_flag=""
  [[ "${DRY_RUN}" == "true" ]] && dry_run_flag="--dry-run"

  local values_args="-f ${values_base}"
  [[ -f "${values_env}" ]] && values_args="${values_args} -f ${values_env}"

  helm upgrade --install iosme-lamar "${HELM_CHART}" \
    --namespace "${NAMESPACE}" \
    ${values_args} \
    --set image.tag="${IMAGE_TAG}" \
    --atomic \
    --timeout "${TIMEOUT}" \
    --create-namespace \
    ${dry_run_flag}

  log "Helm deploy completed successfully"
}

do_rollback() {
  local revision_arg="${REVISION:-}"
  if [[ -n "${revision_arg}" ]]; then
    step "Rolling back iosme-lamar to revision ${revision_arg} in namespace=${NAMESPACE}..."
    helm rollback iosme-lamar "${revision_arg}" --namespace "${NAMESPACE}" --timeout "${TIMEOUT}"
  else
    step "Rolling back iosme-lamar to previous revision in namespace=${NAMESPACE}..."
    helm rollback iosme-lamar --namespace "${NAMESPACE}" --timeout "${TIMEOUT}"
  fi
  log "Rollback completed successfully"
}

post_deploy_verification() {
  step "Post-deployment verification..."

  # Wait for rollout
  log "Waiting for deployment rollout..."
  kubectl rollout status deployment/iosme-app --namespace "${NAMESPACE}" --timeout=5m

  # Show pod status
  log "Pod status:"
  kubectl get pods --namespace "${NAMESPACE}" -l "app.kubernetes.io/name=iosme"

  # Health check
  if [[ "${SKIP_HEALTH_CHECK}" == "false" && -x "${HEALTH_CHECK}" ]]; then
    step "Running health check..."
    "${HEALTH_CHECK}" --env "${ENV}"
  elif [[ "${SKIP_HEALTH_CHECK}" == "true" ]]; then
    warn "Health check skipped (--skip-health-check)"
  fi
}

main() {
  parse_args "$@"
  check_prerequisites

  log "=== IOSME Helm Deployment ==="
  log "Environment : ${ENV}"
  log "Namespace   : ${NAMESPACE}"
  if [[ "${ROLLBACK}" == "true" ]]; then
    log "Action      : ROLLBACK${REVISION:+ to revision ${REVISION}}"
  else
    log "Image Tag   : ${IMAGE_TAG}"
    log "Action      : DEPLOY"
  fi
  log "Timeout     : ${TIMEOUT}"
  [[ "${DRY_RUN}" == "true" ]]         && warn "DRY-RUN mode — no changes will be applied"
  echo ""

  if [[ "${ROLLBACK}" == "false" ]]; then
    pre_deploy_checks
  fi

  if [[ "${ROLLBACK}" == "true" ]]; then
    do_rollback
  else
    do_deploy
  fi

  if [[ "${DRY_RUN}" == "false" ]]; then
    post_deploy_verification
  fi

  log ""
  log "=== Done ==="
}

main "$@"

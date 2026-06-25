#!/usr/bin/env bash
# install-rke2.sh — Install and configure RKE2 on an IOSME node
#
# Usage:
#   ./scripts/install-rke2.sh [OPTIONS]
#
# Options:
#   --role      <server|agent>       Node role (required)
#   --node      <hostname>           Target node hostname (required)
#   --version   <rke2-version>       RKE2 version (default: latest)
#   --server    <url>                RKE2 server URL (required for agent role)
#   --token     <token>              Node join token (required for non-first-server)
#   --first-server                   Flag: this is the first control-plane node
#   --tls-san   <san>                Extra TLS SAN (can be repeated)
#   --gpu                            Flag: configure for GPU node
#   --dry-run                        Print actions without executing
#   -h, --help                       Show help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
ROLE=""
NODE=""
RKE2_VERSION=""
SERVER_URL=""
JOIN_TOKEN=""
FIRST_SERVER=false
GPU_NODE=false
DRY_RUN=false
TLS_SANS=()
CLUSTER_CIDR="10.42.0.0/16"
SERVICE_CIDR="10.43.0.0/16"
CNI="canal"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio.lamar.edu:9000}"
MINIO_BUCKET="rke2-etcd"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}

run_remote() {
  local node="$1"; shift
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}[DRY-RUN on ${node}]${NC} $*"
  else
    ssh -o StrictHostKeyChecking=no "ubuntu@${node}.lamar.edu" "$@"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --role)          ROLE="$2";        shift 2 ;;
      --node)          NODE="$2";        shift 2 ;;
      --version)       RKE2_VERSION="$2"; shift 2 ;;
      --server)        SERVER_URL="$2";  shift 2 ;;
      --token)         JOIN_TOKEN="$2";  shift 2 ;;
      --first-server)  FIRST_SERVER=true; shift  ;;
      --gpu)           GPU_NODE=true;    shift   ;;
      --tls-san)       TLS_SANS+=("$2"); shift 2 ;;
      --dry-run)       DRY_RUN=true;     shift   ;;
      -h|--help)       usage ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  [[ -z "${ROLE}" ]] && die "--role is required (server|agent)"
  [[ -z "${NODE}" ]] && die "--node is required"
  [[ "${ROLE}" =~ ^(server|agent)$ ]] || die "--role must be 'server' or 'agent'"
  if [[ "${ROLE}" == "agent" ]]; then
    [[ -z "${SERVER_URL}" ]] && die "--server is required for agent role"
    [[ -z "${JOIN_TOKEN}" ]] && die "--token is required for agent role"
  fi
  if [[ "${ROLE}" == "server" && "${FIRST_SERVER}" == "false" ]]; then
    [[ -z "${SERVER_URL}" ]] && die "--server is required for non-first-server"
    [[ -z "${JOIN_TOKEN}" ]] && die "--token is required for non-first-server"
  fi
}

build_server_config() {
  local config=""

  if [[ "${FIRST_SERVER}" == "false" ]]; then
    config+="server: ${SERVER_URL}\n"
    config+="token: ${JOIN_TOKEN}\n"
  fi

  # TLS SANs
  if [[ ${#TLS_SANS[@]} -gt 0 ]]; then
    config+="tls-san:\n"
    for san in "${TLS_SANS[@]}"; do
      config+="  - ${san}\n"
    done
  fi

  config+="cluster-cidr: ${CLUSTER_CIDR}\n"
  config+="service-cidr: ${SERVICE_CIDR}\n"
  config+="cni: ${CNI}\n"
  config+="disable:\n"
  config+="  - rke2-ingress-nginx\n"

  # etcd snapshot to S3
  config+="etcd-snapshot-schedule-cron: \"0 */6 * * *\"\n"
  config+="etcd-snapshot-retention: 5\n"
  config+="etcd-s3: true\n"
  config+="etcd-s3-endpoint: ${MINIO_ENDPOINT}\n"
  config+="etcd-s3-bucket: ${MINIO_BUCKET}\n"

  echo -e "${config}"
}

build_agent_config() {
  local config=""
  config+="server: ${SERVER_URL}\n"
  config+="token: ${JOIN_TOKEN}\n"

  if [[ "${GPU_NODE}" == "true" ]]; then
    config+="node-label:\n"
    config+="  - \"node-role.iosme/gpu=true\"\n"
    config+="  - \"accelerator=nvidia\"\n"
  fi

  echo -e "${config}"
}

install_rke2() {
  local node="$1"
  local type="$2"
  local version_flag=""
  [[ -n "${RKE2_VERSION}" ]] && version_flag="INSTALL_RKE2_VERSION=${RKE2_VERSION}"

  log "Installing RKE2 (type=${type}) on ${node}..."
  run_remote "${node}" "curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=${type} ${version_flag} sh -"
}

configure_rke2() {
  local node="$1"
  local config_content="$2"

  log "Writing RKE2 config on ${node}..."
  run_remote "${node}" "sudo mkdir -p /etc/rancher/rke2"
  if [[ "${DRY_RUN}" == "false" ]]; then
    echo -e "${config_content}" | ssh "ubuntu@${node}.lamar.edu" \
      "sudo tee /etc/rancher/rke2/config.yaml > /dev/null"
  else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would write config to /etc/rancher/rke2/config.yaml:"
    echo -e "${config_content}"
  fi
}

start_rke2() {
  local node="$1"
  local svc_name="$2"

  log "Enabling and starting ${svc_name} on ${node}..."
  run_remote "${node}" "sudo systemctl enable ${svc_name} && sudo systemctl start ${svc_name}"
}

wait_for_node_ready() {
  local node="$1"
  log "Waiting for node '${node}' to become Ready (up to 5 minutes)..."
  if [[ "${DRY_RUN}" == "false" ]]; then
    local attempts=0
    while [[ ${attempts} -lt 30 ]]; do
      local status
      status=$(KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl get node "${node}" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
      if [[ "${status}" == "True" ]]; then
        log "Node '${node}' is Ready"
        return 0
      fi
      sleep 10
      attempts=$((attempts + 1))
    done
    warn "Node '${node}' did not become Ready within 5 minutes. Check: kubectl get nodes"
  fi
}

main() {
  parse_args "$@"

  log "=== RKE2 Installation ==="
  log "Node : ${NODE}"
  log "Role : ${ROLE}"
  [[ -n "${RKE2_VERSION}" ]] && log "Version: ${RKE2_VERSION}"
  [[ "${DRY_RUN}" == "true" ]] && warn "DRY-RUN mode"
  echo ""

  if [[ "${ROLE}" == "server" ]]; then
    local config
    config=$(build_server_config)
    install_rke2 "${NODE}" "server"
    configure_rke2 "${NODE}" "${config}"
    start_rke2 "${NODE}" "rke2-server.service"

    if [[ "${FIRST_SERVER}" == "true" ]]; then
      log "Waiting 30 seconds for first server to initialize..."
      [[ "${DRY_RUN}" == "false" ]] && sleep 30
      log "Fetching node join token..."
      if [[ "${DRY_RUN}" == "false" ]]; then
        local token
        token=$(run_remote "${NODE}" "sudo cat /var/lib/rancher/rke2/server/node-token")
        log "Join token (save this for other nodes):"
        echo ""
        echo "  ${token}"
        echo ""
      fi
    fi
  else
    local config
    config=$(build_agent_config)
    install_rke2 "${NODE}" "agent"
    configure_rke2 "${NODE}" "${config}"
    start_rke2 "${NODE}" "rke2-agent.service"
  fi

  wait_for_node_ready "${NODE}"

  log ""
  log "=== RKE2 installation complete on ${NODE} ==="
  if [[ "${ROLE}" == "server" && "${FIRST_SERVER}" == "true" ]]; then
    log "To configure kubectl:"
    log "  scp ubuntu@${NODE}.lamar.edu:/etc/rancher/rke2/rke2.yaml ~/.kube/iosme-prod.yaml"
    log "  sed -i 's/127.0.0.1/iosme-k8s.lamar.edu/' ~/.kube/iosme-prod.yaml"
  fi
}

main "$@"

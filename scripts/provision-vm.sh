#!/usr/bin/env bash
# provision-vm.sh — Provision a new IOSME VM on Lamar University vSphere
#
# Usage:
#   ./scripts/provision-vm.sh [OPTIONS]
#
# Options:
#   --env       <prod|staging|dev>   Target environment (default: prod)
#   --host      <hostname>           VM hostname (e.g. iosme-worker-03)
#   --vcpu      <count>              Number of vCPUs (default: 16)
#   --ram       <GB>                 RAM in GB (default: 64)
#   --disk      <GB>                 OS disk in GB (default: 500)
#   --template  <name>               vSphere template name (default: ubuntu-2204-template)
#   --dry-run                        Print actions without executing
#   -h, --help                       Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults
ENV="prod"
HOSTNAME=""
VCPU=16
RAM_GB=64
DISK_GB=500
TEMPLATE="ubuntu-2204-template"
DRY_RUN=false

VCENTER="vcenter.lamar.edu"
DATACENTER="LU-Datacenter"
CLUSTER="LU-Prod-Cluster"
RESOURCE_POOL="IOSME-Prod"
DATASTORE="LU-NFS-DS01"
NETWORK="LU-VLAN200"
NTP_SERVER="ntp.lamar.edu"
DNS_SERVER="dns.lamar.edu"
SSH_KEY_FILE="${HOME}/.ssh/iosme_ops.pub"

# Colors
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

run() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
  else
    eval "$*"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)      ENV="$2";      shift 2 ;;
      --host)     HOSTNAME="$2"; shift 2 ;;
      --vcpu)     VCPU="$2";     shift 2 ;;
      --ram)      RAM_GB="$2";   shift 2 ;;
      --disk)     DISK_GB="$2";  shift 2 ;;
      --template) TEMPLATE="$2"; shift 2 ;;
      --dry-run)  DRY_RUN=true;  shift   ;;
      -h|--help)  usage ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  [[ -z "${HOSTNAME}" ]] && die "--host is required"
  [[ "${ENV}" =~ ^(prod|staging|dev)$ ]] || die "--env must be prod, staging, or dev"
}

check_prerequisites() {
  log "Checking prerequisites..."
  command -v govc  &>/dev/null || die "govc (VMware CLI) is not installed. Install from https://github.com/vmware/govmomi/releases"
  command -v ssh   &>/dev/null || die "ssh is not installed"
  [[ -f "${SSH_KEY_FILE}" ]]   || die "SSH public key not found: ${SSH_KEY_FILE}"

  [[ -n "${GOVC_URL:-}"      ]] || export GOVC_URL="https://${VCENTER}"
  [[ -n "${GOVC_USERNAME:-}" ]] || die "GOVC_USERNAME environment variable is not set"
  [[ -n "${GOVC_PASSWORD:-}" ]] || die "GOVC_PASSWORD environment variable is not set"
  export GOVC_INSECURE="${GOVC_INSECURE:-false}"

  log "govc version: $(govc version 2>/dev/null || echo 'unknown')"
}

clone_vm() {
  log "Cloning VM '${HOSTNAME}' from template '${TEMPLATE}'..."
  run "govc vm.clone \
    -vm '${DATACENTER}/vm/Templates/${TEMPLATE}' \
    -name '${HOSTNAME}' \
    -folder '${DATACENTER}/vm/IOSME/${ENV}' \
    -resource-pool '${DATACENTER}/host/${CLUSTER}/Resources/${RESOURCE_POOL}' \
    -datastore '${DATASTORE}' \
    -on=false"
}

configure_vm() {
  log "Configuring VM hardware: ${VCPU} vCPU, ${RAM_GB} GB RAM, ${DISK_GB} GB disk..."
  run "govc vm.change -vm '${HOSTNAME}' -c ${VCPU} -m $((RAM_GB * 1024))"
  run "govc vm.disk.change -vm '${HOSTNAME}' -disk.label 'Hard disk 1' -size ${DISK_GB}GB"

  log "Configuring network adapter..."
  run "govc vm.network.change -vm '${HOSTNAME}' -net '${NETWORK}' ethernet-0"
}

power_on_vm() {
  log "Powering on VM '${HOSTNAME}'..."
  run "govc vm.power -on '${HOSTNAME}'"

  log "Waiting for VM to get an IP address (up to 5 minutes)..."
  if [[ "${DRY_RUN}" == "false" ]]; then
    local ip=""
    local attempts=0
    while [[ -z "${ip}" && ${attempts} -lt 30 ]]; do
      sleep 10
      ip=$(govc vm.ip "${HOSTNAME}" 2>/dev/null || true)
      attempts=$((attempts + 1))
    done
    [[ -z "${ip}" ]] && die "VM did not obtain an IP address after 5 minutes"
    log "VM IP address: ${ip}"
    echo "${ip}"
  fi
}

post_provision_setup() {
  local ip="$1"
  log "Running post-provisioning setup on ${HOSTNAME} (${ip})..."

  # Wait for SSH to be available
  local ssh_ready=false
  for i in $(seq 1 12); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
         -i "${SSH_KEY_FILE%.pub}" "ubuntu@${ip}" true 2>/dev/null; then
      ssh_ready=true
      break
    fi
    sleep 10
  done
  [[ "${ssh_ready}" == "false" ]] && die "SSH not available on ${ip} after 2 minutes"

  run "ssh -o StrictHostKeyChecking=no -i '${SSH_KEY_FILE%.pub}' ubuntu@${ip} bash -s" <<'REMOTE'
set -euo pipefail

# Set hostname
sudo hostnamectl set-hostname "$(hostname)"

# Update packages
sudo apt-get update -q
sudo apt-get upgrade -y -q

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Enable kernel modules
sudo modprobe overlay br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Sysctl for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Install common tools
sudo apt-get install -y -q curl jq wget htop ntp fail2ban ufw

# Configure NTP
sudo systemctl enable ntp
sudo systemctl start ntp
REMOTE
}

main() {
  parse_args "$@"
  check_prerequisites

  log "=== IOSME VM Provisioning ==="
  log "Environment : ${ENV}"
  log "Hostname    : ${HOSTNAME}"
  log "vCPU        : ${VCPU}"
  log "RAM         : ${RAM_GB} GB"
  log "Disk        : ${DISK_GB} GB"
  log "Template    : ${TEMPLATE}"
  [[ "${DRY_RUN}" == "true" ]] && warn "DRY-RUN mode enabled — no changes will be made"
  echo ""

  clone_vm
  configure_vm
  local vm_ip
  vm_ip=$(power_on_vm)
  post_provision_setup "${vm_ip}"

  log ""
  log "=== Provisioning complete ==="
  log "VM '${HOSTNAME}' is ready at ${vm_ip}"
  log "Next step: Run ./scripts/install-rke2.sh --role agent --node ${HOSTNAME}"
}

main "$@"

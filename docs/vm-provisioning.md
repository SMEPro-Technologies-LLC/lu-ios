# VM Provisioning — IOSME at Lamar University

This document describes how to provision the virtual machines that form the IOSME infrastructure on Lamar University's vSphere environment.

---

## VM Inventory

| Hostname | vCPU | RAM (GB) | Disk (GB) | Role | Network |
|----------|------|----------|-----------|------|---------|
| iosme-master-01 | 8 | 32 | 200 | RKE2 Server (control plane) | VLAN 200 |
| iosme-master-02 | 8 | 32 | 200 | RKE2 Server (control plane) | VLAN 200 |
| iosme-master-03 | 8 | 32 | 200 | RKE2 Server (control plane) | VLAN 200 |
| iosme-worker-01 | 16 | 64 | 500 | RKE2 Agent (general workloads) | VLAN 200 |
| iosme-worker-02 | 16 | 64 | 500 | RKE2 Agent (general workloads) | VLAN 200 |
| iosme-gpu-01 | 16 | 128 | 500 | RKE2 Agent (GPU inference) | VLAN 200 |
| iosme-db-01 | 8 | 32 | 1000 | PostgreSQL Primary | VLAN 201 |
| iosme-db-02 | 8 | 32 | 1000 | PostgreSQL Replica | VLAN 201 |
| iosme-bastion | 2 | 4 | 50 | Bastion / Jump Host | VLAN 100 + VLAN 200 |

---

## Operating System

All VMs run **Ubuntu 22.04 LTS** (Jammy Jellyfish), minimal install, hardened per Lamar University CIS Level 1 baseline.

---

## vSphere Requirements

- **vCenter**: vcenter.lamar.edu (v8.0+)
- **Cluster**: `LU-Prod-Cluster`
- **Datastore**: `LU-NFS-DS01` (VM OS), `LU-SAN-DS01` (database volumes)
- **Distributed Switch**: `LU-DVS-Prod`
- **Resource Pool**: `IOSME-Prod`

---

## Provisioning via Terraform

See [`terraform/vsphere-vms.tf`](../terraform/vsphere-vms.tf) for the Terraform configuration.

```bash
cd terraform/
terraform init
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

---

## Provisioning via Script

If Terraform is not yet adopted, use the provisioning script:

```bash
./scripts/provision-vm.sh --env prod --host iosme-worker-01
```

See the script source at [`scripts/provision-vm.sh`](../scripts/provision-vm.sh).

---

## Post-Provisioning Checklist

- [ ] SSH key-based access verified from bastion
- [ ] Hostname set and resolvable in LU DNS
- [ ] NTP synchronized to `ntp.lamar.edu`
- [ ] Firewall rules applied (see Security section)
- [ ] `/etc/hosts` entries propagated across all nodes
- [ ] Swap disabled (`swapoff -a` + `/etc/fstab` entry removed)
- [ ] `br_netfilter` and `overlay` kernel modules loaded
- [ ] `net.bridge.bridge-nf-call-iptables=1` and `net.ipv4.ip_forward=1` set
- [ ] NVIDIA driver installed on `iosme-gpu-01` (see [GPU Inference docs](gpu-inference.md))

---

## Firewall Rules (VLAN 200 — Kubernetes)

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| Workers | Masters | 9345 | TCP | RKE2 supervisor |
| All nodes | All nodes | 6443 | TCP | Kubernetes API |
| All nodes | All nodes | 10250 | TCP | kubelet |
| All nodes | All nodes | 8472 | UDP | Flannel VXLAN |
| All nodes | All nodes | 51820 | UDP | WireGuard (Canal) |
| Bastion | All nodes | 22 | TCP | SSH management |

---

## Security Hardening

- Root SSH login disabled
- `ufw` enabled; only required ports open
- Fail2ban installed and configured
- Kernel live patching enabled via `ubuntu-advantage-tools`
- CIS benchmark applied via Ansible (contact LU IT for playbook)

---

## References

- [RKE2 Node Requirements](https://docs.rke2.io/install/requirements)
- [Runbook 01 — VM Provisioning](../runbooks/01-vm-provisioning.md)

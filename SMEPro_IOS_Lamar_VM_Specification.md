# IOS+ Lamar Edition — VM Deployment Specification

**Document:** SME-IOS-LU-VM-SPEC-001  
**Target Platform:** VMware vSphere (Lamar ITIS-managed)  
**Guest OS:** Red Hat Enterprise Linux 9.x (or RHEL 8.x if ITIS standard is 8)  
**Hypervisor:** VMware vSphere (verified in Lamar ITIS Systems Administrator Senior job posting)  
**Storage Backend:** SAN/NAS (verified existing)  
**Network:** LUnet backbone, VLAN-segmented  
**Reference:** SME-IOS-LU-FINAL-001 §01.1 Cluster Topology, §01.2 Networking, §08 Kubernetes Delivery & Infrastructure Cap clauses

---

## 1. Infrastructure Cap Compliance

Per §08 Infrastructure Cap clause: **Maximum six compute nodes** (VM or bare-metal). HPA scaling within deployment replicas is permitted. No seventh node without written Lamar request. This specification allocates exactly six VMs.

---

## 2. VM Inventory

| VM Name | vSphere Host | Role | vCPU | RAM | OS Disk | Data Disk | Network | GPU | Notes |
|---------|-------------|------|------|-----|---------|-----------|---------|-----|-------|
| `lu-ios-api-01` | Any (anti-affinity with api-02) | API Gateway + Policy Engine | 8 | 32 GB | 100 GB thin | 200 GB thin | LUnet-VLAN-IOS (10.244.x.x/16) | None | Primary API ingress node |
| `lu-ios-api-02` | Any (anti-affinity with api-01) | API Gateway + Celery Worker | 8 | 32 GB | 100 GB thin | 200 GB thin | LUnet-VLAN-IOS (10.244.x.x/16) | None | Secondary API + Celery worker pool |
| `lu-ios-db-01` | Dedicated or vSphere DRS rule | PostgreSQL 15 Primary | 16 | 64 GB | 100 GB thin | 2 TB thick-eager (NVMe tier if available) | LUnet-VLAN-IOS (10.244.x.x/16) | None | Streaming replication source |
| `lu-ios-db-02` | Dedicated or vSphere DRS rule (anti-affinity with db-01) | PostgreSQL 15 Replica + Evidence Fabric | 16 | 64 GB | 100 GB thin | 4 TB thick-eager (NVMe tier if available) | LUnet-VLAN-IOS (10.244.x.x/16) | None | 7-year retention, SHA-256 chain, ECDSA |
| `lu-ios-gpu-01` | GPU-enabled ESXi host | Local Inference + Embeddings | 16 | 128 GB | 100 GB thin | 1 TB thin | LUnet-VLAN-IOS (10.244.x.x/16) | 2× NVIDIA L40S 48GB (PCIe passthrough or vGPU) | Ollama / vLLM, Llama 3.3 70B INT8, BGE-M3 |
| `lu-ios-svc-01` | Any | Shared Services | 8 | 32 GB | 100 GB thin | 200 GB thin | LUnet-VLAN-IOS (10.244.x.x/16) | None | Redis 7, NGINX Ingress, Prometheus, Grafana, LTI 1.3 |

**Total:** 72 vCPU · 352 GB RAM · ~6 TB storage (OS + Data) · 2× NVIDIA L40S 48GB

---

## 3. vSphere Configuration Details

### 3.1 Resource Pools

Create a dedicated vSphere Resource Pool named `RP-IOSPlus-Lamar` with:
- **CPU Reservation:** 64 GHz (leaves 8 GHz headroom for HPA burst)
- **RAM Reservation:** 320 GB (leaves 32 GB headroom)
- **CPU Limit:** 80 GHz (hard cap for noisy-neighbor isolation)
- **RAM Limit:** 384 GB
- **Shares:** High (relative to general academic workload VMs)

### 3.2 VM Templates

Base VM template (clone for all six):
- **OS:** Red Hat Enterprise Linux 9.3 (or ITIS-standard RHEL version)
- **Kernel:** 5.14.x (RHEL 9) or 4.18.x (RHEL 8) with `kernel-devel` and `kernel-headers`
- **Disk Format:** Thin provisioned for OS; thick-eager for database data (performance + pre-allocation)
- **Network Adapter:** VMXNET3 (LUnet standard, 10 Gbps capable)
- **SCSI Controller:** PVSCSI (higher IOPS for database workloads)
- **Firmware:** UEFI (required for GPU passthrough on some hosts)
- **Guest OS Customization:** Standard ITIS hostname, IP, DNS, NTP (`ntp.lamar.edu` or `time.lamar.edu`)

### 3.3 RHEL Subscription & Repositories

Each VM requires:
- RHEL 9 BaseOS + AppStream subscriptions (via Lamar's existing Satellite or RHSM)
- EPEL repository (disabled by default, enabled for `containerd`, `kubernetes` packages)
- CRB (CodeReady Builder) for `nvidia-driver` compilation dependencies (gpu-01 only)

### 3.4 GPU Configuration (lu-ios-gpu-01)

**Critical Gap:** If Lamar's VMware cluster does not have NVIDIA L40S (or A10 / A100 / V100 / RTX A6000) GPUs installed, this VM cannot be deployed. See §6 Fallback.

If GPU exists:
- **vSphere Configuration:** DirectPath I/O (PCIe passthrough) or NVIDIA vGPU (vSphere 7.0+ with NVIDIA vGPU license)
- **Recommended:** DirectPath I/O for maximum performance (Llama 70B requires ~48 GB VRAM per GPU; 2× L40S = 96 GB total, allowing 70B INT8 + KV cache overhead)
- **NVIDIA Driver:** 535.x or 545.x (latest production branch, compatible with CUDA 12.2+)
- **NVIDIA Container Toolkit:** Installed post-Kubernetes provisioning for GPU device plugin
- **vGPU Alternative:** If vGPU is used (e.g., 2× A10 24GB = 48 GB total), INT8 quantization may still fit 70B but KV cache will be constrained. Test before production.

---

## 4. Kubernetes Provisioning

### 4.1 Kubernetes Distribution

Recommended for Lamar ITIS (RHEL shop): **Rancher Kubernetes Engine 2 (RKE2)** or **vanilla kubeadm on RHEL 9**.

**RKE2 Rationale:**
- Air-gap friendly (Lamar may have egress restrictions)
- CIS-hardened by default (aligns with TAC 202 and ISO requirements)
- systemd-native on RHEL
- Simpler for ITIS staff who may not have deep K8s expertise

**kubeadm Rationale:**
- More standard documentation and community support
- Better control over CNI and CSI choices
- Longer-term flexibility if Lamar wants to migrate to OpenShift later

**Recommendation:** Start with **RKE2** for Phase 1; migrate to kubeadm or OpenShift in Year 2 if Lamar Platform Engineer prefers standard tooling.

### 4.2 Node Roles

| VM | RKE2 Role | Kubernetes Labels | Taints |
|----|-----------|------------------|--------|
| lu-ios-api-01 | Server (control plane) + Worker | `node-role.kubernetes.io/api=true`, `node-role.kubernetes.io/control-plane=true` | `node-role.kubernetes.io/control-plane:NoSchedule` (remove for worker) |
| lu-ios-api-02 | Worker | `node-role.kubernetes.io/api=true` | None |
| lu-ios-db-01 | Worker | `node-role.kubernetes.io/db=true` | `node-role.kubernetes.io/db=true:NoSchedule` |
| lu-ios-db-02 | Worker | `node-role.kubernetes.io/db=true` | `node-role.kubernetes.io/db=true:NoSchedule` |
| lu-ios-gpu-01 | Worker | `node-role.kubernetes.io/gpu=true`, `nvidia.com/gpu.present=true` | `node-role.kubernetes.io/gpu=true:NoSchedule` |
| lu-ios-svc-01 | Worker | `node-role.kubernetes.io/svc=true` | None |

### 4.3 CNI: Calico (Recommended)

```yaml
# Calico IP Pool for IOS+ pod network
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: ios-pool
spec:
  cidr: 10.244.0.0/16
  natOutgoing: true
  disabled: false
  nodeSelector: all()
```

**Rationale:** Calico is well-documented, supports NetworkPolicy (required for Banner replica isolation), and integrates cleanly with RHEL. Cilium is an alternative if eBPF and Hubble observability are desired.

### 4.4 CSI: vSphere CSI Driver (Recommended)

Since Lamar runs VMware vSphere, the **vSphere Container Storage Interface (CSI)** driver is the native choice.

```yaml
# StorageClass for IOS+ workloads
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ios-san-fast
provisioner: csi.vsphere.vmware.com
parameters:
  storagepolicyname: "Lamar-IOS-Fast"  # vSphere Storage Policy created by ITIS
  # Or: datastoreurl if not using SPBM
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**ITIS Action Required:** Create a vSphere Storage Policy (`Lamar-IOS-Fast`) mapped to the SAN LUN or datastore with NVMe/SSD tier for database workloads. A second policy (`Lamar-IOS-Standard`) for general workloads.

### 4.5 GPU Operator (lu-ios-gpu-01)

Install **NVIDIA GPU Operator** via Helm after RKE2 cluster is up:

```bash
helm install nvidia-gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=true \
  --set toolkit.enabled=true \
  --set devicePlugin.enabled=true
```

**Note:** If using DirectPath I/O, ensure `nouveau` kernel module is blacklisted on gpu-01 before GPU Operator installation.

---

## 5. OS-Level Configuration (Per VM)

### 5.1 Common (All VMs)

```bash
# RHEL 9 baseline hardening (ITIS standard + K8s requirements)
# 1. Disable swap (Kubernetes requirement)
swapoff -a
sed -i '/swap/d' /etc/fstab

# 2. Firewall — allow K8s ports (if firewalld is running)
firewall-cmd --permanent --add-port=6443/tcp   # K8s API
firewall-cmd --permanent --add-port=10250/tcp  # Kubelet
firewall-cmd --permanent --add-port=2379/tcp   # etcd (if control plane)
firewall-cmd --permanent --add-port=2380/tcp   # etcd peer
firewall-cmd --reload

# 3. SELinux — set to Permissive for Phase 1; Enforce after hardening
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
# Note: §04 pen-test requires SELinux Enforcing before go-live.

# 4. NTP synchronization
systemctl enable --now chronyd

# 5. Hostname and /etc/hosts
# Use ITIS DNS; if not available, populate /etc/hosts with all 6 IPs
```

### 5.2 Database Nodes (db-01, db-02)

```bash
# PostgreSQL 15 tuning for VM environment
# vm.swappiness = 1 (already disabled, but safety)
# vm.dirty_ratio = 15
# vm.dirty_background_ratio = 5
# vm.overcommit_memory = 2
# vm.overcommit_ratio = 95
# kernel.shmmax = 68719476736  (64 GB)
# kernel.shmall = 16777216

cat >> /etc/sysctl.conf << 'EOF'
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 2
vm.overcommit_ratio = 95
kernel.shmmax = 68719476736
kernel.shmall = 16777216
EOF
sysctl -p

# IO scheduler — deadline or mq-deadline for SAN-backed disks
echo 'mq-deadline' > /sys/block/sda/queue/scheduler
# (or sdb for data disk — depends on vSphere device mapping)
```

### 5.3 GPU Node (gpu-01)

```bash
# Blacklist nouveau
 cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

# NVIDIA driver installation (if not handled by GPU Operator)
# Use NVIDIA's RHEL 9 repo via Lamar's Satellite if available
# Or download from nvidia.com and install manually:
# sh NVIDIA-Linux-x86_64-535.154.05.run --silent --no-opengl-files

# Verify
drm -r /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/nouveau
mkinitrd
reboot

# Post-reboot: nvidia-smi should show 2× L40S
```

---

## 6. GPU Fallback Decision Matrix

If `lu-ios-gpu-01` cannot be provisioned due to absent GPU hardware:

| Scenario | Fallback | Impact | Action |
|----------|----------|--------|--------|
| **No GPU on any ESXi host** | Deploy gpu-01 as CPU-only (16 vCPU, 128 GB RAM) | Llama 3.3 70B INT8 on CPU: ~2–5 tokens/sec, ~8–12 concurrent max, 30+ sec latency per request | Tier 1 inference degraded; faculty may experience slow response. Acceptable for pilot. |
| **1× L40S available** | Deploy gpu-01 with 1× GPU + CPU offload | 70B INT8 may fit with aggressive quantization (INT4 AWQ/GPTQ) or smaller model (Llama 3.1 8B for pilot, 70B for production) | SOW amendment: §01.1 cluster topology notes 1× GPU as pilot config; 2× for production. |
| **No on-prem GPU; OCI GPU available** | Hybrid: gpu-01 as OCI VM (GPU shape), other 5 on-prem | Bandwidth/latency to OCI for every Tier 1 request; ~50–100 ms added RTT | Science DMZ / FastConnect path must have headroom; GPU node in OCI adds ~$3K–$5K/month. |
| **No GPU anywhere** | Tier 1 entirely via CPU; Tier 2/3 (Anthropic) unchanged | Sovereign inference effectively unavailable; all inference externalized | Violates "sovereign inference" architectural goal. Faculty Senate AI Working Group must ratify. |

**Recommendation:** If no GPU is available, proceed with **Scenario A** (CPU-only) for Phase 1–3 pilot, then procure 2× L40S before Phase 4 hardening. The CPU-only pilot validates all integration paths (Banner, Blackboard, Concourse, M365) without the GPU dependency.

---

## 7. VM Naming & DNS

| VM Name | Internal FQDN | IP (DHCP or Static) | DNS Record |
|---------|--------------|---------------------|------------|
| lu-ios-api-01 | lu-ios-api-01.lamar.edu | Static (ITIS allocation) | A record in lamar.edu zone |
| lu-ios-api-02 | lu-ios-api-02.lamar.edu | Static | A record |
| lu-ios-db-01 | lu-ios-db-01.lamar.edu | Static | A record |
| lu-ios-db-02 | lu-ios-db-02.lamar.edu | Static | A record |
| lu-ios-gpu-01 | lu-ios-gpu-01.lamar.edu | Static | A record |
| lu-ios-svc-01 | lu-ios-svc-01.lamar.edu | Static | A record |
| **Ingress VIP** | ios-lti.lamar.edu | MetalLB or F5 VIP | A record pointing to LB |

**ITIS Action:** Allocate static IPs from the IOS+ VLAN subnet and create A records in the `lamar.edu` DNS zone (forward + reverse). Lamar ITS owns all root resolvers per Network Use Policy 10.03.04.

---

## 8. Backup & Snapshot Policy

| VM | Backup Method | Frequency | Retention | Owner |
|----|--------------|-----------|-----------|-------|
| All VMs | vSphere Snapshot | Pre-upgrade only | 1 snapshot | ITIS (standard) |
| lu-ios-db-01 | PostgreSQL pgBackRest + WAL archiving | Continuous | 7 days WAL + weekly full | SMEPro (Phase 1–6) → Lamar Platform Engineer |
| lu-ios-db-02 | Streaming replica + nightly export | Real-time + nightly | 7-year chain (Evidence Fabric) | SMEPro → Lamar |
| lu-ios-db-01/02 | SAN snapshot (if supported by ITIS) | Weekly | 4 weeks | ITIS (if available) |

**Note:** vSphere snapshots are **not** a backup method for database VMs — they cause performance degradation and should only be used for pre-upgrade rollback. PostgreSQL native backup (pgBackRest) is the production standard.

---

## 9. HPA & Scaling Limits

Per §08 Infrastructure Cap: HPA is permitted within the six-node count. The following HPA rules are configured in the Helm chart but cannot scale beyond node resources.

| Deployment | Min Replicas | Max Replicas | HPA Trigger | Ceiling |
|------------|-------------|-------------|-------------|---------|
| API Gateway | 2 | 6 | CPU > 70% | 6 pods across 2 API nodes (8 vCPU each) |
| Celery Worker | 2 | 6 | Queue depth > 100 | 6 pods across 2 API nodes |
| LTI 1.3 Service | 1 | 3 | CPU > 80% | 3 pods on svc-01 node |

**Hard Limit:** No pod scheduling beyond the 72 vCPU / 352 GB RAM aggregate. If sustained load exceeds this, the infrastructure cap clause requires written Lamar request for expansion.

---

## 10. Deliverables Checklist

| Item | Delivered By | Format | Reviewer |
|------|-------------|--------|----------|
| VM sizing spec (this doc) | SMEPro | Markdown | Lamar IT Director, ITIS Lead |
| vSphere Resource Pool config | SMEPro | vSphere config export + Word doc | ITIS VMware Admin |
| RHEL kickstart / cloud-init templates | SMEPro | Kickstart + cloud-init YAML | ITIS Linux Admin |
| RKE2 cluster provisioning script | SMEPro | Bash + RKE2 config YAML | Lamar IOS+ Platform Engineer |
| VM provisioning runbook (Day 1) | SMEPro | Markdown + ITIS-specific notes | ITIS Network Engineer |
| Post-provisioning validation script | SMEPro | Python + kubectl | Lamar IOS+ Platform Engineer |

---

*End of VM Specification.*

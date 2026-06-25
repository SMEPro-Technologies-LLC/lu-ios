# SMEPro IOS+ · Lamar University Infrastructure Alignment

**Document:** SME-IOS-LU-INFRA-ALIGN-001  
**Purpose:** Map the Intelligence Orchestration System (IOS+) powered by the COS Universal Decoding Matrix against Lamar University’s verified production infrastructure to identify insertion points, gaps, and provisioning requirements.  
**Classification:** For Lamar IT Director, Provost office, and General Counsel review.  
**Sources:** Lamar University policy documents, Oracle reference architectures, LEARN consortium reports, official job postings, NSF cyberinfrastructure publications, and the Joint Technical Specification (SME-IOS-LU-FINAL-001).

---

## 1. Executive Summary

Lamar University (Beaumont, TX) operates a hybrid infrastructure anchored in **Oracle Cloud Infrastructure (OCI)** for its mission-critical Ellucian Banner ERP, with on-premises data centers running **VMware**, **Red Hat Enterprise Linux**, and **SAN/NAS** storage. The university is a member of the **Texas State University System (TSUS)** and connects to the **LEARN** (Lonestar Education and Research Network) consortium, including a **10 Gbps NSF-funded Science DMZ** for research data transfer. Identity flows through **Microsoft Entra ID / Active Directory**, collaboration runs on **Microsoft 365**, and the learning management system is **Anthology Blackboard Ultra**.

The SMEPro IOS+ proposal (six-node Kubernetes cluster, 72 vCPU / 352 GB RAM / ~6 TB NVMe / 2× NVIDIA L40S 48GB) can be inserted into this infrastructure at **three possible tiers**, each with different ownership, cost, and operational implications. This document evaluates all three and recommends the path that minimizes Lamar’s net-new capital expenditure while preserving the security and compliance posture required by the SOW.

---

## 2. Verified Lamar University Production Infrastructure

### 2.1 Executive & Organizational

| Element | Verified Detail | Source |
|---------|----------------|--------|
| **CIO** | Patrick Stewart | LEARN 2021–2023 Annual Reports |
| **IT Division** | Information Technology Services (ITS) | Faculty Handbook, Catalog |
| **Infrastructure Department** | Information Technology Infrastructure Services (ITIS) | Network Management Policy 10.03.04 |
| **Security** | Information Security Office (ISO) + Security Operations Center (SOC) | Network Use Policy |
| **Compliance** | TAC 202, Texas Education Code §51.215, FERPA, SACSCOC | Board of Regents materials, Policies |
| **Service Desk** | (409) 880-2222, servicedesk@lamar.edu | Faculty Handbook, Catalog |
| **System Admin** | RHCSA/RHCE certifications required for senior roles | Job postings (2026) |

### 2.2 Cloud & ERP Infrastructure

| Element | Verified Detail | Source |
|---------|----------------|--------|
| **Primary Cloud** | **Oracle Cloud Infrastructure (OCI)** | Oracle reference architecture case studies |
| **Primary Region** | OCI Ashburn | Oracle “Migrate Ellucian Banner ERP in a Multiregion Deployment on OCI” |
| **DR Region** | OCI Phoenix (warm standby) | Oracle multiregion architecture docs |
| **ERP** | **Ellucian Banner** (XE production DB) | Oracle reference architectures, ERP Analyst job posting |
| **Banner Components** | SSB (Student/Admin), Degree Works, Ethos API, AppXtender, Automic, Flywire | Oracle Tharseo case study |
| **Database** | **Oracle Database Enterprise Edition** (Banner DB, DW DB, Degree Works DB) | Oracle architecture docs |
| **Connectivity** | OCI FastConnect + site-to-site VPN (active-standby) | Oracle case study |
| **Storage** | OCI Object Storage (backups), OCI File Storage (config) | Oracle architecture docs |
| **Monitoring** | Oracle Cloud Observability & Management Platform | Oracle case study |
| **Batch / Workflow** | Automic (UC4/AppWorx) | ERP Analyst job posting |
| **Reporting** | PL/SQL, SQL, Oracle Data Warehouse, Evisions (desired) | ERP Analyst job posting |

### 2.3 On-Premises Infrastructure

| Element | Verified Detail | Source |
|---------|----------------|--------|
| **Virtualization** | **VMware vSphere** (hypervisor) | Systems Administrator Senior job posting |
| **OS** | **Red Hat Enterprise Linux** (primary), Windows Server | Job posting, Network Policy |
| **Storage** | **SAN / NAS** enterprise storage systems | Job posting |
| **Physical Facilities** | ITS Data Centers — environmental monitoring, security cameras, intrusion alarms, access-controlled | IT Physical Access / Environmental Security Policy 10.03.05 |
| **Network** | **LUnet** — campus backbone, wired LANs, wireless (secure + open), VPN | Network Management Policy 10.03.04 |
| **DNS/DHCP** | Centralized ITS ownership | Network Use Policy |
| **Science DMZ** | **10 Gbps** research network, 5TB+ SSD RAID, **Perfsonar**, **Globus**, single-mode fiber | Lamar.edu Science DMZ page, NSF workshop |
| **Research Connectivity** | **LEARN** (Lonestar Education and Research Network) | LEARN Annual Reports, NSF workshop |

### 2.4 Identity, Collaboration & End-User Systems

| Element | Verified Detail | Source |
|---------|----------------|--------|
| **Identity** | **Active Directory** + **Microsoft Entra ID** | Oracle architecture (CAS/SSO via Entra ID), M365 |
| **Email / Collaboration** | **Microsoft 365** (Exchange Online, Teams, OneDrive, Outlook, Word, Excel, PowerPoint) | LU Press (2020), LU Online tech support |
| **Student Portal** | **LU Connect** (aggregates LEA, email, Blackboard, SSB, Office 365, housing, billing) | Lamar University Press |
| **LMS** | **Anthology Blackboard Ultra** (LU Learn) | LMS Policy MAPP 02.04.18, LU Online |
| **Syllabus** | **Concourse** (Intellidemia SaaS) | Joint Technical Specification §01 |
| **Video** | **YuJa** | LU Online tech support |
| **Tutoring** | **Brainfuse** | LU Online tech support |
| **Credentialing** | **Milestone Achievement Studio** (Anthology) | LU Online |
| **Career** | **Handshake** (Hire a Cardinal) | LU Press |
| **Timekeeping** | **TimeClock Plus** (implemented Nov 2024) | Board of Regents May 2025 |
| **Other** | myScholarships, Financial Avenue, Aviso (retention) | LU Press, Oracle architecture |

### 2.5 Security & Compliance Posture

| Element | Verified Detail | Source |
|---------|----------------|--------|
| **Framework** | TAC 202, Texas Government Code §2054, FERPA, Texas Education Code §51.215 | Network Use Policy, Info Systems Mgmt Policy 10.01.01 |
| **Perimeter** | DMZ, firewalls, IDS/IPS, application firewalls, malware scanners, DLP | Network Management Policy |
| **Network Segmentation** | Interior segmentation, traffic shaping, VLANs | Network Use Policy |
| **Wireless** | Modern enterprise security only; older standards deprecated | Network Management Policy |
| **TLS** | TLS 1.3 referenced in modern specs; SSL/IPsec/SSH for sensitive data | Network Use Policy |
| **Audit** | Security Awareness & Training Audit (March 2024) — 7 recommendations in progress | Board of Regents May 2025 |
| **Banner Access** | Logical Access Controls Audit (April 2023) — exemptions under Govt Code 552.139 (network security) | Board of Regents May 2025 |
| **Security-Sensitive** | Critical infrastructure roles subject to Cyber Intelligence Review per EO GA-48 | ERP Analyst job posting |

---

## 3. IOS+ Deployment Requirements (from SME-IOS-LU-FINAL-001)

### 3.1 Compute & Cluster Topology

The IOS+ middleware runs as a **6-node Kubernetes cluster** totaling **72 vCPU, 352 GB RAM, ~6 TB NVMe**. The proposal explicitly states: *“deploy as VMs on Lamar's existing VMware vSphere or Proxmox cluster”* or as bare-metal hosts.

| Node | Role | Resources | Workload |
|------|------|-----------|----------|
| **k8s-api-01** | API Gateway + Policy Engine | 8 vCPU · 32 GB RAM | FastAPI ingress, ABAC/RBAC, request normalization |
| **k8s-api-02** | API Gateway + Celery Worker | 8 vCPU · 32 GB RAM | Second API replica, Celery worker pool (concurrency=4) |
| **k8s-db-01** | PostgreSQL Primary | 16 vCPU · 64 GB RAM · 2 TB NVMe | PostgreSQL 15, UCO nodes, audit records, policy versions, streaming replication source |
| **k8s-db-02** | PostgreSQL Replica + Evidence Fabric | 16 vCPU · 64 GB RAM · 4 TB NVMe | Streaming replica, SHA-256 audit chain, 7-year retention, ECDSA signing |
| **k8s-gpu-01** | Local Inference + Embeddings | 16 vCPU · 128 GB RAM · **2× NVIDIA L40S 48GB** | Ollama/vLLM, Llama 3.3 70B INT8, BGE-M3 embeddings, Tier 1 sovereign inference |
| **k8s-svc-01** | Shared Services | 8 vCPU · 32 GB RAM | Redis 7, NGINX Ingress Controller, Prometheus + Grafana, LTI 1.3 Tool Provider |

### 3.2 Networking Requirements

| Requirement | IOS+ Spec | Lamar Existing |
|-------------|-----------|----------------|
| **Container CNI** | Calico or Cilium, pod subnet 10.244.0.0/16 | Not verified — would be net-new K8s overlay |
| **Service Mesh** | None required at this scale | N/A |
| **Ingress** | NGINX Ingress Controller, TLS 1.3, cert-manager, rate limiting | **F5 load balancer** referenced as existing option in IOS+ spec; Lamar has F5 or MetalLB on-prem |
| **Outbound Anthropic** | HTTPS to `api.anthropic.com`, **no TLS inspection/MITM** | Must be validated against Lamar edge appliances |
| **Outbound Microsoft** | Standard M365/Graph endpoints | Already permitted per M365 EDU tenant |
| **Storage** | Longhorn or existing SAN for PVCs; 10 TB allocated; WORM object storage for audit chain | **SAN/NAS exists**; WORM object storage may require provisioning |
| **FQDN** | One Lamar-owned FQDN for LTI endpoint | **Lamar owns `lamar.edu` domain** — subdelegation available via ITIS |
| **Banner replication** | Port 5432/tcp (TLS-wrapped) from Banner → IOS+ replica pod | **New firewall rule** required within LUnet |

### 3.3 Integration Touchpoints

| System | IOS+ Needs | Lamar Status |
|--------|-----------|--------------|
| **Blackboard Ultra** | LTI 1.3 Advantage (AGS, NRPS, Deep Linking 2.0), JWS keypair, platform deployment ID | **Must be confirmed active** — not enabled by default on all Blackboard Ultra tenants (SOW §06) |
| **Banner XE** | OAuth 2.0 client credentials, `REPLICATION` role on filtered tables (course catalog, curriculum, CIP codes), Ethos API for writebacks | **Running on OCI** — scope strings must be verified by Banner DBA against running release |
| **Concourse** | OAuth 2.0 client credential, read scope on template layers, write scope on section layer (faculty-gated) | SaaS hosted by Intellidemia — API access is a configuration ask, not infrastructure |
| **Microsoft 365 / Copilot** | Entra ID app registration (confidential client, certificate-based auth), Graph permissions: `AuditLog.Read.All`, `Directory.Read.All`, `Reports.Read.All`, `AiEnterpriseInteraction.Read.All`, Purview eDiscovery Premium | **Existing tenant** — app registration is a standard IAM workflow; Purview eDiscovery Premium may require license verification |
| **Anthropic API** | ZDR (Zero Data Retention) contractual addendum; API key custodied in Vault | **Net-new vendor relationship** — no existing contract verified |

### 3.4 Security & Compliance Artifacts

| Requirement | IOS+ Spec | Lamar Alignment |
|-------------|-----------|-----------------|
| **Secret Management** | HashiCorp Vault (Enterprise recommended) | **Unverified** — if not held, this is a procurement dependency |
| **Observability** | Prometheus + Grafana (default in IOSME repo); Datadog as alternative | **Unverified** — Lamar runs Oracle Cloud Observability for OCI; on-prem APM not confirmed |
| **Audit Chain** | SHA-256 + ECDSA-secp256k1, 7-year retention, quarterly DR exercise | **New operational process** — must be staffed by Lamar Platform Engineer |
| **Penetration Test** | Independent third-party before production (Phase 4) | **Likely existing vendor** — NCC Group, Bishop Fox, or Lamar’s security partner |
| **FERPA Boundary** | No direct Banner DB mutation; all writebacks via Ethos with HITL approval and TraceID | **Aligns with Banner audit posture** — Banner Logical Access Controls Audit already scoped |

---

## 4. Three Deployment Insertion Options

### Option A: On-Premises VMs on Existing VMware (Recommended)

**Mechanism:** Deploy the six IOS+ nodes as VMs on Lamar’s existing **VMware vSphere** cluster, managed by ITIS.

**Alignment:**
- **VMware** is explicitly cited in the Systems Administrator Senior job posting as the production hypervisor.
- **RHEL** is the primary OS for enterprise servers — compatible with Kubernetes (RHEL supports OpenShift or vanilla K8s via kubeadm/RKE2).
- **SAN/NAS** storage can serve as the PersistentVolume backend (via vSphere CSI or existing NFS/iSCSI).
- **LUnet** network backbone provides the LAN connectivity; only new requirement is the 5432/tcp rule for Banner replication and the Anthropic egress rule.
- **DNS** subdelegation for the LTI FQDN is standard ITIS workflow (Lamar ITS owns all root resolvers for `lamar.edu`).

**Lamar Must Provide:**
1. 6 VM slots (or physical hosts if preferred) with the resource profile above.
2. One **NVIDIA L40S 48GB** (or equivalent) GPU — or two if the spec is strict. **Critical gap:** GPU presence in Lamar’s VMware cluster is **unverified** in any public source. If absent, this is a capital purchase (~$15K–$20K per L40S, or GPU-as-a-service via cloud burst).
3. Subnet/VLAN allocation for the K8s pod network (10.244.0.0/16) without conflict.
4. Firewall rule: Banner XE → IOS+ k8s-db-02 on 5432/tcp (TLS-wrapped).
5. Firewall rule: IOS+ cluster → `api.anthropic.com` 443/tcp, **bypassing TLS inspection**.
6. FQDN registration (e.g., `iosplus.lamar.edu` or `lti-ios.lamar.edu`) via ITIS.

**SMEPro Must Provide:**
- Helm chart production artifact (per §08 clause).
- 40 hours pair-programming with Lamar IOS+ Platform Engineer (per §08 clause).
- Documentation for ITIS firewall rule requests.

**Cost Impact:** Lowest capital if GPU already exists. If GPU is absent, this is the single largest hardware gap.

---

### Option B: Oracle Cloud Infrastructure (OCI) — Co-Resident with Banner

**Mechanism:** Deploy the six IOS+ nodes as **OCI Compute VMs** within the same OCI tenancy that already hosts Banner, connected via the existing VCN and site-to-site VPN.

**Alignment:**
- Lamar already operates a **multi-region OCI deployment** (Ashburn primary, Phoenix standby).
- The existing **site-to-site VPN** and **FastConnect** provide campus connectivity.
- **Oracle Cloud Observability** already monitors Banner — can extend to IOS+ nodes.
- **OCI Object Storage** can serve as WORM backup target for the Evidence Fabric (replacing Longhorn/nightly export).
- **OCI Base Database Service** is already in use — however, IOS+ requires **PostgreSQL 15**, not Oracle. This would run as a separate VM or OCI-managed PostgreSQL if available.

**Lamar Must Provide:**
1. OCI tenancy expansion: 6 additional Compute instances (or equivalent shape in OCI).
2. **GPU shape** in OCI: OCI offers NVIDIA A10/L40S GPU instances, but this is a **cost-bearing** service (not a sunk cost like on-prem hardware).
3. VCN subnet allocation for IOS+ pods (must not overlap with Banner subnets).
4. Security List / Network Security Group rules: Banner DB subnet → IOS+ DB subnet on 5432/tcp; IOS+ subnet → `api.anthropic.com` egress.
5. OCI Object Storage bucket with **retention-lock / WORM** for audit chain export (replaces on-prem WORM requirement).

**SMEPro Must Provide:**
- OCI-compatible Helm chart (same artifact, different PVC/storage class configuration).
- DR runbook adapted for OCI cross-region (leveraging existing Phoenix standby region).

**Cost Impact:** Higher recurring OPEX (OCI GPU compute is premium). Lower upfront capital. Aligns with Lamar’s existing cloud-first ERP strategy.

**Risk:** The SOW states *“on-premises Kubernetes · Lamar-hosted”* on the cover. Moving to OCI is a **contractual change** unless the SOW language is amended to allow cloud-native deployment. The §08 “Infrastructure cap” clause caps at six nodes regardless of location.

---

### Option C: Hybrid — Control Plane On-Prem, GPU/Inference Burst to OCI or Cloud

**Mechanism:** Keep the four non-GPU nodes (k8s-api-01/02, k8s-db-01/02, k8s-svc-01) on-prem at Lamar, and run the **GPU inference node (k8s-gpu-01)** as a cloud-burst instance or via **LEARN/NSF cloud resources**.

**Alignment:**
- **LEARN** consortium members often have access to shared research computing resources (e.g., NSF XSEDE-adjacent capacity).
- Lamar’s **Science DMZ** (10 Gbps) is designed for high-bandwidth research data flows — could serve as the backhaul to a GPU inference endpoint without traversing the general campus firewall.
- **Four non-GPU nodes** fit cleanly into existing VMware capacity without exotic hardware.

**Lamar Must Provide:**
1. On-prem VMs for 5 nodes (40 vCPU, 224 GB RAM, ~4 TB NVMe).
2. Network path from Science DMZ or campus edge to cloud GPU endpoint — or acceptance of Tier 1 inference latency over a remote link.
3. If using LEARN/shared resources: coordination with LEARN board (CIO Patrick Stewart sits on the LEARN board of directors).

**SMEPro Must Provide:**
- Architecture for split-brain Kubernetes (control plane on-prem, GPU worker remote) — adds operational complexity.
- Fallback to CPU-only inference (Tier 1 on CPU) if remote GPU is unavailable — performance drops to ~2–5 tokens/sec for Llama 70B.

**Cost Impact:** Lowest on-prem footprint. Highest complexity and latency risk. Not recommended for production unless LEARN GPU resources are contractually guaranteed.

---

## 5. Gap Analysis & Provisioning Requirements

### 5.1 Hardware Gaps (Unverified — Require ITIS Discovery)

| Gap | Verification Action | Owner | Priority |
|-----|--------------------|-------|----------|
| **GPU availability** | Does Lamar’s VMware cluster already host NVIDIA GPUs (A10, L40S, A100, V100)? | Lamar ITIS | **CRITICAL** |
| **NVMe storage** | Does existing SAN/NAS provide NVMe-tier storage, or is it all-flash SSD/HDD? | Lamar ITIS | **HIGH** |
| **K8s substrate** | Does Lamar already run any Kubernetes cluster (vanilla, OpenShift, Rancher)? | Lamar ITIS | **HIGH** |
| **Bare-metal capacity** | If VMs are not preferred, does ITIS have 6 physical server slots? | Lamar ITIS | **MEDIUM** |

### 5.2 Software/License Gaps

| Gap | Verification Action | Owner | Priority |
|-----|--------------------|-------|----------|
| **HashiCorp Vault** | Does Lamar already hold Vault Enterprise or OSS licenses? | Lamar ITIS / Procurement | **HIGH** |
| **Datadog / APM** | Does Lamar already use Datadog, New Relic, or similar? If not, Prometheus+Grafana is the fallback. | Lamar ITIS | **MEDIUM** |
| **LTI Advantage** | Confirm with Anthology that AGS, NRPS, Deep Linking 2.0 are active on the Blackboard Ultra tenant. | Lamar Blackboard Admin | **CRITICAL** |
| **M365 Purview eDiscovery Premium** | Verify licensing level for `AiEnterpriseInteraction.Read.All` and Purview eDiscovery API access. | Lamar M365 / Identity Engineer | **HIGH** |
| **Anthropic ZDR** | Confirm no existing Anthropic contract; negotiate ZDR addendum as new vendor. | SMEPro (facilitate) + Lamar Procurement | **CRITICAL** |

### 5.3 Network & Firewall Gaps

| Gap | Rule / Configuration | Owner | Priority |
|-----|--------------------|-------|----------|
| **Banner replication** | Allow 5432/tcp from Banner XE (OCI or on-prem) to IOS+ k8s-db-02, TLS-wrapped | Lamar Network Engineer + Banner DBA | **CRITICAL** |
| **Anthropic egress** | Allow 443/tcp outbound from IOS+ cluster to `api.anthropic.com`, **TLS inspection bypass** | Lamar Network Engineer + ISO | **CRITICAL** |
| **LTI ingress** | Allow 443/tcp inbound to IOS+ k8s-svc-01 from Blackboard SaaS (Anthology hosted) | Lamar Network Engineer + ITIS | **HIGH** |
| **K8s pod network** | Allocate 10.244.0.0/16 (or equivalent) without conflict with LUnet addressing | Lamar Network Engineer | **HIGH** |
| **FQDN / DNS** | Register LTI endpoint subdomain (e.g., `ios-lti.lamar.edu`) under `lamar.edu` | Lamar ITIS | **HIGH** |

### 5.4 Personnel Gaps (Aligned with Resource Plan §04)

| Role | IOS+ Spec | Lamar Status | Action |
|------|-----------|------------|--------|
| **IOS+ Platform Engineer** | 1.0 FTE, hired/assigned in Phase 0, pairs with SMEPro | **Unfilled** | Hire or assign from existing ITIS staff before Phase 0 |
| **Compliance Analyst** | 0.5 FTE, co-authors education-only UCO pack | **Unfilled** | Hire or assign from Institutional Research / Compliance |
| **Banner DBA** | 0.4 FTE for replica setup, Ethos, OAuth scope verification | **Exists** | Confirm availability for Phase 1 milestone |
| **Blackboard Administrator** | 0.3 FTE for LTI 1.3 registration, Advantage confirmation | **Exists** | Confirm availability for Phase 0 milestone |
| **M365 / Identity Engineer** | 0.3 FTE for Entra ID app, Graph permissions, Purview | **Exists** (implied by M365 tenant) | Confirm availability for Phase 2 |
| **Network Engineer** | 0.25 FTE for K8s ingress, firewall rules, Anthropic egress | **Exists** (implied by ITIS) | Confirm availability for Phase 1 |

---

## 6. Alignment Against Oracle OCI Architecture (Banner Co-Hosting)

Lamar’s Banner ERP runs on OCI with a specific subnet topology: Application, Database, Edge/Bastion, Shared Services, Management. The IOS+ cluster, if deployed in OCI, would need a **new subnet** (e.g., `IOSPlus-Subnet`) peered with the existing VCN.

| OCI Component | Banner Usage | IOS+ Usage | Coexistence |
|---------------|------------|------------|-------------|
| **VCN** | `Lamar-VCN` (existing) | Same VCN or peered VCN | **Peered VCN recommended** — keeps IOS+ network policies isolated from Banner’s security zones |
| **Application Subnet** | Banner Admin, SSB, Degree Works VMs | k8s-api-01/02, k8s-svc-01 | Separate subnets; no overlap |
| **Database Subnet** | Oracle Base Database Service (Banner DB, DW, Degree Works) | k8s-db-01/02 (PostgreSQL 15) | **Different DB engine** — no conflict; separate subnets |
| **Edge/Bastion** | Jump servers for admin access | Bastion host for K8s control plane access | Can share or separate |
| **Object Storage** | Banner backups, config files | WORM audit chain export, Helm artifact storage | **Same service, different buckets** |
| **FastConnect / VPN** | Campus-to-OCI connectivity | Same pipes — bandwidth headroom must be verified | **Critical:** Add ~500 MB/day (Graph/Purview) + Anthropic API traffic to existing Banner VPN load |
| **DR Region (Phoenix)** | Standby DB via Data Guard, Rackware staging | Secondary replica of k8s-db-02 Evidence Fabric | **Aligns with SOW DR requirement** — reuse Phoenix region for IOS+ audit chain DR |
| **Cloud Guard** | Monitors Banner tenancy security posture | Extend to IOS+ VCN | **Same tool, new tenancy policies** |

**Key Insight:** If Lamar chooses Option B (OCI), the existing DR investment in **Phoenix** can be leveraged for the IOS+ Evidence Fabric by replicating `k8s-db-02` to a standby VM in Phoenix. This satisfies the SOW’s “RPO ≤ 15 min, RTO ≤ 4 hours” clause with minimal incremental cost.

---

## 7. Alignment Against Science DMZ / LEARN Network

Lamar’s **Science DMZ** provides a **10 Gbps** research path with a **Perfsonar** node and **Globus** data transfer. This is relevant to IOS+ in two ways:

1. **Network Performance Baseline:** The Science DMZ proves Lamar has high-bandwidth, low-latency fiber paths. If the IOS+ GPU node is on-prem, the K8s cluster can be physically adjacent to the DMZ switching infrastructure for high-bandwidth internal traffic (e.g., large model checkpoint transfers, embedding vector syncs).

2. **Research Computing Precedent:** Lamar has already run NSF-funded infrastructure projects. If GPU capacity is a gap, a **supplemental NSF grant** for “AI governance infrastructure for STEM education” could fund the L40S nodes. The PI would need to tie the request to existing research programs (e.g., Center for Resiliency, engineering, or data analytics).

**Recommendation:** If GPU hardware is absent and capital is constrained, explore whether the **LEARN consortium** or **NSF CC*DNI** program can subsidize GPU infrastructure for the IOS+ Tier 1 inference node, given the alignment with Lamar’s existing cyberinfrastructure investments.

---

## 8. Recommended Deployment Path

**Primary Recommendation: Option A (On-Premises VMs) with conditional GPU fallback.**

### Rationale
1. **VMware + RHEL + SAN** are all verified, production-hardened infrastructure at Lamar. ITIS already administers these systems daily.
2. **Network integration** is minimal: two firewall rules, one DNS entry, one subnet allocation. ITIS owns all these functions.
3. **Security boundary** remains inside Lamar’s existing TAC 202 / ISO / SOC perimeter. No new cloud tenancy to secure.
4. **Banner replication** on port 5432 stays inside LUnet — no WAN traversal, lower latency, simpler compliance.
5. **Personnel continuity** — the IOS+ Platform Engineer and Compliance Analyst are hired into Lamar staff, operating alongside existing ITIS, Banner DBA, and Blackboard Admin teams.

### Conditional GPU Decision Tree
```
Does Lamar VMware cluster already have NVIDIA GPU capacity?
├─ YES → Deploy k8s-gpu-01 as a VM on existing GPU host. Done.
└─ NO  → Is capital budget available for 2× L40S 48GB (~$30K–$40K)?
    ├─ YES → Procure and install GPU nodes in ITIS data center.
    └─ NO  → Fallback to Option B (OCI GPU instances) for k8s-gpu-01 only,
              with control plane on-prem. OR reduce to 1× L40S and accept
              throughput ceiling (~15–25 tokens/sec, 8–12 concurrent sessions).
```

### If OCI is Preferred (Option B)
Lamar has already committed to OCI as its strategic cloud for ERP. If the Provost and IT Director prefer to centralize all compute in OCI, the SOW cover language (*“on-premises Kubernetes · Lamar-hosted”*) should be amended to *“Lamar-hosted · OCI tenant-managed”* or similar. The §08 infrastructure cap still applies (6 nodes). The WORM audit chain export can use OCI Object Storage with retention-lock, satisfying the DR clause without on-prem hardware.

---

## 9. Pre-SOW Verification Checklist

Before SOW signature, Lamar IT should verify the following against the clauses in §08 of the Joint Technical Specification:

| # | Verification Item | Lamar Owner | Evidence Needed | Maps to §08 Clause |
|---|-------------------|-------------|-----------------|--------------------|
| 1 | VMware cluster capacity for 6 VMs (72 vCPU, 352 GB RAM, 6 TB storage) | IT Director / ITIS | vCenter resource report | Infrastructure cap |
| 2 | GPU inventory (NVIDIA L40S, A10, or equivalent) | ITIS | Hardware audit | Infrastructure cap |
| 3 | Kubernetes existence (vanilla, OpenShift, or none) | ITIS | Cluster inventory | Kubernetes delivery |
| 4 | HashiCorp Vault license status | ITIS / Procurement | License entitlements | TCO disclosure |
| 5 | LTI Advantage (AGS, NRPS, Deep Linking 2.0) active on Blackboard tenant | Blackboard Admin | Anthology tenant console screenshot or support ticket | LTI Advantage confirmation |
| 6 | Banner OAuth scope strings for course catalog / curriculum / CIP read-only | Banner DBA | Banner XE API documentation for installed release | Banner OAuth scope verification |
| 7 | M365 Purview eDiscovery Premium license status | M365 / Identity Engineer | Admin center license report | TCO disclosure |
| 8 | Firewall rule feasibility for 5432/tcp and Anthropic egress | Network Engineer | Firewall rule review meeting notes | — |
| 9 | Subnet availability for 10.244.0.0/16 or equivalent | Network Engineer | IPAM / LUnet addressing plan | — |
| 10 | FQDN delegation process for `lamar.edu` subdomain | ITIS | DNS delegation workflow | — |
| 11 | WORM storage capability (on-prem SAN or OCI Object Lock) | ITIS / Storage Admin | Storage feature matrix | Audit chain DR |
| 12 | Anthropic ZDR addendum draft in procurement | Procurement / General Counsel | Contract redline | Anthropic ZDR confirmation |
| 13 | Penetration test vendor under existing contract or new procurement | ISO / Security | Vendor list or procurement requisition | TCO disclosure |
| 14 | IOS+ Platform Engineer headcount approved | Provost / HR | Position control document | Knowledge transfer |
| 15 | Compliance Analyst headcount approved | Provost / HR | Position control document | Knowledge transfer |

---

## 10. Document Sources & Citations

1. **Oracle Reference Architecture:** *“Migrate Ellucian Banner ERP to Oracle Cloud Using FastConnect and Rackware”* — docs.oracle.com, June 2023. Documents Lamar’s OCI Ashburn/Phoenix multi-region deployment, Banner components, DB topology, and FastConnect/VPN connectivity.

2. **Oracle Reference Architecture:** *“Migrate Ellucian Banner ERP in a Multiregion Deployment on Oracle Cloud”* — docs.oracle.com, June 2023. Documents OCI VCN subnet layout, security zones, Cloud Guard, Object Storage, and DR topology.

3. **LEARN Annual Reports (2021–2023)** — tx-learn.org. Confirms Patrick Stewart as CIO; LEARN board membership; consortium networking.

4. **Lamar University Job Postings (2026):** *“System Administrator Senior”* — careers.insidehighered.com, Job #202600142. Confirms VMware hypervisor, RHEL, SAN/NAS, data center operations, monitoring systems.

5. **Lamar University Job Postings (2026):** *“ERP Analyst Information Technology”* — ziprecruiter.com, Job #202600034. Confirms Banner ERP, Oracle SQL, Microsoft SQL, PL/SQL, Evisions, AppWorx/Automic, Ethos, ERP security.

6. **Lamar University Faculty Handbook / Catalog** — lamar.edu. Confirms ITS division, Banner SSB, Blackboard LMS, M365 email, wireless Internet, Service Desk location and contact.

7. **Network Management Policy 10.03.04** — lamar.edu. Documents LUnet backbone, wired/wireless/VPN, TAC 202 compliance, ISO/SOC responsibilities, DNS/DHCP ownership, IP address management.

8. **Network Use Policy 10.03.04** — lamar.edu. Documents network device definitions, segmentation, wireless standards, server registration, scanning prohibitions, metadata logging.

9. **IT Physical Access / Environmental Security Policy 10.03.05** — lamar.edu. Documents data center physical security, camera, alarm, environmental monitoring, visitor access controls.

10. **Information Systems Management Policy 10.01.01** — lamar.edu. Documents PKI, certificate standards, cryptography, collaborative computing, name/address resolution security controls.

11. **Lamar University Science DMZ** — lamar.edu/it-services-and-support/science-dmz. Documents 10 Gbps bandwidth, LEARN connectivity, 5TB+ SSD RAID, Perfsonar, Globus, NSF grant, single-mode fiber.

12. **NSF Cyberinfrastructure PI Workshop** — tx-learn.org. Documents Lamar’s Science DMZ abstract, 10G routed ports, DMZ switches, high-performance data transfer node, Perfsonar node.

13. **Lamar University Press (2020):** *“LEA account offers wide range of services”* — lamaruniversitypress.com. Documents LU Connect, Blackboard, SSB, M365, housing, billing, Handshake, myScholarships, Financial Avenue.

14. **LU Online Technology Support** — lamar.edu. Documents Blackboard Ultra, YuJa, Qwickly, Brainfuse, Milestone Achievement Studio, servicedesk@lamar.edu.

15. **LMS Policy MAPP 02.04.18** — lamar.edu. Documents Anthology Blackboard Ultra as official enterprise LMS, SIS integration, LTI 1.3, policy enforcement.

16. **Texas State University System Board of Regents (May 2025)** — docs.gato.txst.edu. Documents Banner Logical Access Controls Audit (April 2023), Security Awareness & Training Audit (March 2024), TimeClock Plus implementation (Nov 2024), Patrick Stewart as CFO-referenced IT executive.

17. **GovTech (2022):** *“Lamar University Project Aims to Defend Energy Infrastructure”* — govtech.com. Documents Lamar’s cybersecurity and data analytics research centers, regional infrastructure partnerships.

18. **SMEPro / IOS+ Joint Technical Specification (SME-IOS-LU-FINAL-001)** — ios_plus_lamar_FINAL_v2.html, June 2026. Documents the proposed IOS+ 6-node K8s cluster, Helm chart, integration requirements, performance baselines, §07 Risk Register, and §08 Contract Clauses.

---

*End of Document.*

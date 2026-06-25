# iosme-ops — Lamar University iOS Mobile Experience Operations

This repository contains all operational artifacts for deploying, managing, and maintaining the **IOSME** (iOS Mobile Experience) platform at Lamar University. It is maintained by the Lamar University IT/DevOps team in partnership with SMEPro Technologies.

---

## Repository Layout

```
iosme-ops/
├── README.md                       ← this file
├── docs/                           ← reference documentation
│   ├── vm-provisioning.md
│   ├── kubernetes-setup.md
│   ├── helm-deployment.md
│   ├── secret-management.md
│   ├── database-operations.md
│   ├── gpu-inference.md
│   ├── integrations/
│   │   ├── banner.md
│   │   ├── blackboard-lti.md
│   │   ├── concourse.md
│   │   └── microsoft-365.md
│   ├── observability.md
│   └── audit-chain-dr.md
├── runbooks/                       ← step-by-step incident/operational runbooks
│   ├── 01-vm-provisioning.md
│   ├── 02-helm-deploy-upgrade-rollback.md
│   ├── 03-postgres-replication-lag.md
│   ├── 04-gpu-inference-failure.md
│   ├── 05-banner-oauth-refresh.md
│   ├── 06-lti-launch-failure.md
│   ├── 07-anthropic-api-failure.md
│   └── 08-audit-chain-integrity.md
├── scripts/                        ← automation shell scripts
│   ├── provision-vm.sh
│   ├── install-rke2.sh
│   ├── deploy-iosme.sh
│   ├── backup-verify.sh
│   ├── dr-exercise.sh
│   └── health-check.sh
├── helm/
│   └── iosme-lamar/                ← Helm chart (transferred from SMEPro)
└── terraform/
    └── vsphere-vms.tf              ← optional vSphere IaC
```

---

## Quick Start

### Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| `kubectl` | 1.28+ | Kubernetes CLI |
| `helm` | 3.14+ | Chart management |
| `rke2` | 1.30+ | Kubernetes distribution |
| `terraform` | 1.8+ | vSphere VM provisioning |
| `jq` | 1.6+ | JSON processing in scripts |

### Deploy IOSME

```bash
# 1. Provision VMs (or use existing)
./scripts/provision-vm.sh --env prod

# 2. Bootstrap Kubernetes with RKE2
./scripts/install-rke2.sh --role server --node iosme-master-01

# 3. Deploy the IOSME Helm chart
./scripts/deploy-iosme.sh --env prod --version 2.5.0
```

---

## Environments

| Environment | Namespace | Ingress FQDN |
|------------|-----------|--------------|
| Production | `iosme-prod` | `iosme.lamar.edu` |
| Staging | `iosme-staging` | `iosme-staging.lamar.edu` |
| Development | `iosme-dev` | `iosme-dev.lamar.edu` |

---

## Key Contacts

| Role | Team / Person |
|------|--------------|
| Platform Owner | Lamar University IT |
| Application Vendor | SMEPro Technologies LLC |
| On-Call (Level 1) | LU IT Help Desk — helpdesk@lamar.edu |
| On-Call (Level 2) | LU DevOps Team — devops@lamar.edu |
| Vendor Support | SMEPro Support — support@smepro.com |

---

## Documentation Index

- [VM Provisioning](docs/vm-provisioning.md)
- [Kubernetes Setup](docs/kubernetes-setup.md)
- [Helm Deployment](docs/helm-deployment.md)
- [Secret Management](docs/secret-management.md)
- [Database Operations](docs/database-operations.md)
- [GPU Inference](docs/gpu-inference.md)
- [Observability](docs/observability.md)
- [Audit Chain & DR](docs/audit-chain-dr.md)
- **Integrations**
  - [Banner SIS](docs/integrations/banner.md)
  - [Blackboard LTI](docs/integrations/blackboard-lti.md)
  - [Concourse CI/CD](docs/integrations/concourse.md)
  - [Microsoft 365](docs/integrations/microsoft-365.md)

---

## License

Copyright © Lamar University. Internal use only. Not for public distribution.
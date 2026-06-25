# lu-ios — Lamar University IOSME Operations

This repository contains all operational artifacts for deploying, managing, and maintaining the **IOSME** (Intelligence Orchestration System — iOS Mobile Experience) platform at Lamar University. It is maintained by SMEPro Technologies LLC in partnership with the Lamar University IT/DevOps team.

---

## Repository Layout

```
lu-ios/
├── README.md                         ← this file
├── CONTRIBUTING.md                   ← contribution guidelines
├── CODEOWNERS                        ← default reviewers
├── .editorconfig                     ← editor formatting defaults
├── .gitignore
│
├── iosme-lamar/                      ← primary Helm chart (v1.0.0, production)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-lamar-prod.yaml
│   ├── values-lamar-dev.yaml
│   └── templates/
│
├── helm/
│   └── iosme-lamar/                  ← Helm chart v2.5.0 (upstream/staged)
│
├── manifests/                        ← standalone Kubernetes YAML files
│   ├── README.md
│   ├── namespace.yaml
│   ├── api-deployment.yaml
│   ├── worker-deployment.yaml
│   ├── postgres-statefulset.yaml
│   ├── redis-deployment.yaml
│   ├── migrations-job.yaml
│   ├── ingress.yaml
│   ├── network-policies.yaml
│   ├── GlobalNetworkPolicy.yaml
│   ├── certmanager.yaml
│   └── secret.yaml
│
├── docs/                             ← reference documentation
│   ├── vm-provisioning.md
│   ├── kubernetes-setup.md
│   ├── helm-deployment.md
│   ├── secret-management.md
│   ├── database-operations.md
│   ├── gpu-inference.md
│   ├── observability.md
│   ├── audit-chain-dr.md
│   ├── integrations/
│   │   ├── banner.md
│   │   ├── blackboard-lti.md
│   │   ├── concourse.md
│   │   └── microsoft-365.md
│   ├── operations/                   ← step-by-step operational procedures
│   │   ├── deployment-steps.md
│   │   ├── predeployment-checklist.md
│   │   ├── rollback-steps.md
│   │   ├── upgrade-steps.md
│   │   └── handoff-and-versioning.md
│   └── specs/                        ← vendor/infrastructure specification documents
│       ├── helm-chart-production-artifact.md
│       ├── infrastructure-alignment.md
│       └── vm-specification.md
│
├── runbooks/                         ← incident response runbooks
│   ├── 01-vm-provisioning.md
│   ├── 02-helm-deploy-upgrade-rollback.md
│   ├── 03-postgres-replication-lag.md
│   ├── 04-gpu-inference-failure.md
│   ├── 05-banner-oauth-refresh.md
│   ├── 06-lti-launch-failure.md
│   ├── 07-anthropic-api-failure.md
│   └── 08-audit-chain-integrity.md
│
├── scripts/                          ← automation shell scripts
│   ├── provision-vm.sh
│   ├── install-rke2.sh
│   ├── deploy-iosme.sh
│   ├── backup-verify.sh
│   ├── dr-exercise.sh
│   └── health-check.sh
│
└── terraform/
    └── vsphere-vms.tf                ← vSphere VM provisioning (IaC)
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

### Reference Docs
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

### Operational Procedures
- [Deployment Steps](docs/operations/deployment-steps.md)
- [Pre-deployment Checklist](docs/operations/predeployment-checklist.md)
- [Rollback Steps](docs/operations/rollback-steps.md)
- [Upgrade Steps](docs/operations/upgrade-steps.md)
- [Handoff & Versioning](docs/operations/handoff-and-versioning.md)

### Specification Documents
- [Helm Chart Production Artifact](docs/specs/helm-chart-production-artifact.md)
- [Infrastructure Alignment](docs/specs/infrastructure-alignment.md)
- [VM Specification](docs/specs/vm-specification.md)

### Runbooks
- [01 — VM Provisioning](runbooks/01-vm-provisioning.md)
- [02 — Helm Deploy / Upgrade / Rollback](runbooks/02-helm-deploy-upgrade-rollback.md)
- [03 — Postgres Replication Lag](runbooks/03-postgres-replication-lag.md)
- [04 — GPU Inference Failure](runbooks/04-gpu-inference-failure.md)
- [05 — Banner OAuth Refresh](runbooks/05-banner-oauth-refresh.md)
- [06 — LTI Launch Failure](runbooks/06-lti-launch-failure.md)
- [07 — Anthropic API Failure](runbooks/07-anthropic-api-failure.md)
- [08 — Audit Chain Integrity](runbooks/08-audit-chain-integrity.md)

---

## License

Copyright © Lamar University. Internal use only. Not for public distribution.
# Handoff Matrix

| Item                                    | Delivered By | Format           | Handoff Gate | Reviewer                            |
| --------------------------------------- | ------------ | ---------------- | ------------ | ----------------------------------- |
| Helm chart source (`iosme-lamar/`)      | SMEPro       | GitHub repo      | Phase 1      | Lamar IOS+ Platform Engineer        |
| `values-lamar-prod.yaml`                | SMEPro       | YAML             | Phase 1      | Lamar ITIS, Platform Engineer       |
| `values-lamar-dev.yaml`                 | SMEPro       | YAML             | Phase 1      | Lamar Platform Engineer             |
| Chart packaging script (`helm package`) | SMEPro       | Bash             | Phase 1      | Platform Engineer                   |
| Cosign/GPG signing keys                 | SMEPro       | Public key file  | Phase 1      | Lamar Security / ISO                |
| Deployment runbook (this doc)           | SMEPro       | Markdown         | Phase 1      | Platform Engineer, ITIS             |
| Upgrade/rollback runbook                | SMEPro       | Markdown         | Phase 1      | Platform Engineer                   |
| Secret management guide (Vault + ESO)   | SMEPro       | Markdown         | Phase 1      | Platform Engineer, ITIS             |
| Network policy validation script        | SMEPro       | Python + kubectl | Phase 2      | Platform Engineer, Network Engineer |
| Helm chart unit tests (if applicable)   | SMEPro       | Helm test hooks  | Phase 2      | Platform Engineer                   |

# Versioning Plan

| Version | Date    | Changes                                           | Signed Off By                                   |
| ------- | ------- | ------------------------------------------------- | ----------------------------------------------- |
| 1.0.0   | Phase 1 | Initial production artifact                       | SMEPro Architect + Lamar IOS+ Platform Engineer |
| 1.0.1   | Phase 2 | Post-integration fixes (if any)                   | Platform Engineer                               |
| 1.1.0   | Phase 4 | Post-pen-test hardening changes                   | Platform Engineer + ISO                         |
| 2.0.0   | Year 2  | Major platform upgrade (operator migration, etc.) | Platform Engineer + SMEPro Premium Support      |

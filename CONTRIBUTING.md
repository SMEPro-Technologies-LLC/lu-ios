# Contributing to lu-ios

Thank you for contributing to the **IOSME — Lamar University** operations repository.
This repository is maintained by SMEPro Technologies LLC in partnership with Lamar University IT.

---

## Who Can Contribute

| Role | Scope |
|------|-------|
| SMEPro Platform Engineers | All directories |
| Lamar University IT / DevOps | `docs/`, `runbooks/`, `scripts/`, `manifests/` |
| Lamar University Stakeholders | `docs/` — documentation reviews only |

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready, protected |
| `feature/<short-name>` | New features or infrastructure additions |
| `fix/<short-name>` | Bug fixes and patch updates |
| `docs/<short-name>` | Documentation-only changes |

All changes to `main` must go through a pull request with at least **one approval** from a CODEOWNER.

---

## Pull Request Guidelines

1. **Title**: Use a short imperative sentence (e.g., `Add GPU node affinity to worker deployment`).
2. **Description**: Describe *what* changed and *why*. Link to any relevant issue or runbook.
3. **Scope**: Keep PRs focused — one logical change per PR.
4. **Secrets**: Never commit credentials, kubeconfigs, `.tfvars` files with real values, or `.env` files.
   Run `git diff --staged` before committing to verify.
5. **Helm chart changes**: Run `helm lint` before opening a PR:
   ```bash
   helm lint ./iosme-lamar
   helm lint ./helm/iosme-lamar
   ```
6. **Terraform changes**: Run `terraform fmt` and `terraform validate`:
   ```bash
   cd terraform && terraform fmt && terraform validate
   ```
7. **Shell scripts**: Verify with `shellcheck` if available:
   ```bash
   shellcheck scripts/*.sh
   ```

---

## Commit Message Style

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body]
[optional footer]
```

**Types:** `feat`, `fix`, `docs`, `chore`, `refactor`, `ci`, `test`
**Scopes:** `helm`, `terraform`, `scripts`, `manifests`, `docs`, `runbooks`

**Examples:**
```
feat(helm): add PodDisruptionBudget for lti-service
fix(scripts): correct namespace flag in health-check.sh
docs(runbooks): update GPU inference failure runbook
chore: add .editorconfig and CODEOWNERS
```

---

## Reporting Issues

For operational incidents, follow the runbooks in [`runbooks/`](runbooks/).
For repository issues or questions, open a GitHub Issue with a clear description.

---

## Contact

| Team | Contact |
|------|---------|
| SMEPro Platform Team | platform@smepro.io |
| Lamar University IT / DevOps | devops@lamar.edu |

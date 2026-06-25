# Observability — IOSME Monitoring, Logging & Alerting

This document describes the observability stack for the IOSME platform at Lamar University.

---

## Stack Overview

| Layer | Tool | Namespace |
|-------|------|-----------|
| Metrics | Prometheus (kube-prometheus-stack) | `monitoring` |
| Dashboards | Grafana | `monitoring` |
| Log aggregation | Loki + Promtail | `monitoring` |
| Distributed tracing | Tempo (optional) | `monitoring` |
| Alerting | Alertmanager → PagerDuty / Email | `monitoring` |

---

## Deployment

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Deploy kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm/iosme-lamar/observability-values.yaml

# Deploy Loki stack
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=50Gi
```

---

## Accessing Grafana

```bash
# Get the Grafana admin password
kubectl get secret kube-prometheus-stack-grafana \
  --namespace monitoring \
  -o jsonpath="{.data.admin-password}" | base64 --decode

# Port-forward locally
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 --namespace monitoring
# Open: http://localhost:3000
```

Grafana is also accessible at `https://grafana-iosme.lamar.edu` (ingress protected by LDAP SSO).

---

## Key Dashboards

| Dashboard | Grafana ID | Purpose |
|-----------|------------|---------|
| Kubernetes Cluster Overview | 6417 | Node/Pod health |
| NGINX Ingress Controller | 9614 | Request rates, latency |
| PostgreSQL | 9628 | DB performance |
| NVIDIA DCGM Exporter | 12239 | GPU utilization |
| IOSME Application | custom | App-specific metrics |

---

## Prometheus Scrape Targets

The following services expose `/metrics` and are scraped by Prometheus:

- `iosme-app` — application metrics (requests, errors, latency)
- `iosme-ollama` — inference request counts, token throughput
- `postgres-exporter` — PostgreSQL metrics
- `dcgm-exporter` — GPU metrics
- `ingress-nginx` — NGINX metrics
- `rke2` node components

---

## Alert Rules

Alert rules are defined in `helm/iosme-lamar/templates/prometheusrule.yaml`. Key alerts:

| Alert | Condition | Severity | Runbook |
|-------|-----------|----------|---------|
| `IOSMEAppDown` | No healthy pods for 2 min | critical | RB-02 |
| `IOSMEHighErrorRate` | HTTP 5xx rate > 5% | warning | RB-02 |
| `IOSMEPostgresReplicationLag` | Lag > 30 s | critical | RB-03 |
| `IOSMEGPUHighMemory` | GPU mem > 90% | warning | RB-04 |
| `IOSMEGPUDown` | No GPU device detected | critical | RB-04 |
| `IOSMEAnthropicAPIError` | API error rate > 10% | warning | RB-07 |
| `IOSMEAuditChainIntegrity` | Hash verification failure | critical | RB-08 |

---

## Alertmanager Configuration

Alerts are routed to:
1. **PagerDuty** (critical severity) — LU IT on-call rotation
2. **Email** (warning severity) — devops@lamar.edu

```yaml
# alertmanager.yaml snippet
route:
  group_by: ['alertname', 'namespace']
  receiver: 'pagerduty-critical'
  routes:
    - match:
        severity: warning
      receiver: 'email-warning'

receivers:
  - name: 'pagerduty-critical'
    pagerduty_configs:
      - routing_key: '<PAGERDUTY_INTEGRATION_KEY>'
  - name: 'email-warning'
    email_configs:
      - to: 'devops@lamar.edu'
        from: 'alertmanager@lamar.edu'
        smarthost: 'smtp.lamar.edu:587'
```

---

## Log Querying (Loki)

```logql
# All IOSME application logs in last hour
{namespace="iosme-prod", app="iosme-app"} |= "" | logfmt

# Filter errors
{namespace="iosme-prod", app="iosme-app"} |= "level=error"

# Banner OAuth errors
{namespace="iosme-prod"} |= "banner" |= "oauth" |= "error"
```

---

## References

- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Loki](https://grafana.com/docs/loki/latest/)
- [Runbook 02 — Helm Deploy/Upgrade/Rollback](../runbooks/02-helm-deploy-upgrade-rollback.md)

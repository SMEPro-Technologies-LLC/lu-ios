# GPU Inference — IOSME AI Features

IOSME leverages GPU-accelerated inference for on-premises AI workloads (embedding generation, lightweight LLM inference). The GPU node is `iosme-gpu-01`.

---

## Hardware

| Field | Value |
|-------|-------|
| Node | iosme-gpu-01.lamar.edu |
| GPU | NVIDIA A40 48 GB (1×) |
| CUDA | 12.x |
| Driver | 545.x |

---

## Software Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| NVIDIA Container Toolkit | 1.14+ | GPU access in containers |
| NVIDIA Device Plugin | 0.15+ | Kubernetes GPU resource |
| Ollama | latest | Local LLM serving |
| NVIDIA DCGM Exporter | 3.x | GPU metrics for Prometheus |

---

## Driver Installation (iosme-gpu-01)

```bash
# Add NVIDIA package repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-driver-545 nvidia-container-toolkit

# Reboot and verify
reboot
nvidia-smi
```

---

## Kubernetes NVIDIA Device Plugin

```bash
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update

helm upgrade --install nvdp nvdp/nvidia-device-plugin \
  --namespace kube-system \
  --set tolerations[0].key=nvidia.com/gpu \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule

# Verify the GPU resource is available
kubectl get nodes iosme-gpu-01 -o json | jq '.status.capacity["nvidia.com/gpu"]'
```

---

## Ollama Deployment

The IOSME Helm chart deploys Ollama as a sidecar/sub-chart. Key values in `values-prod.yaml`:

```yaml
ollama:
  enabled: true
  image:
    tag: "0.3.12"
  resources:
    limits:
      nvidia.com/gpu: 1
      memory: 48Gi
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  nodeSelector:
    node-role.iosme/gpu: "true"
  models:
    - llama3.2
    - nomic-embed-text
```

---

## Pulling Models

```bash
# Port-forward to the Ollama service locally
kubectl port-forward svc/iosme-ollama 11434:11434 -n iosme-prod

# Pull required models
curl http://localhost:11434/api/pull -d '{"name":"llama3.2"}'
curl http://localhost:11434/api/pull -d '{"name":"nomic-embed-text"}'

# List available models
curl http://localhost:11434/api/tags | jq '.models[].name'
```

---

## Anthropic API Fallback

When local GPU inference is unavailable or for tasks requiring a more capable model, IOSME falls back to the **Anthropic Claude API**. The API key is stored in the `iosme-anthropic-api-key` secret (see [Secret Management](secret-management.md)).

Failure handling for the Anthropic API is described in [Runbook 07](../runbooks/07-anthropic-api-failure.md).

---

## GPU Monitoring

GPU metrics are exported to Prometheus via DCGM Exporter:

```bash
helm upgrade --install dcgm-exporter \
  gpu-helm-charts/dcgm-exporter \
  --namespace monitoring \
  --set tolerations[0].key=nvidia.com/gpu \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule
```

Key Grafana dashboard: **NVIDIA DCGM Exporter Dashboard** (ID: 12239).

Alerting rules (in kube-prometheus-stack):
- GPU utilization < 10% for > 30 min during inference load → alert
- GPU memory > 90% → alert
- GPU temperature > 80°C → alert

---

## References

- [Runbook 04 — GPU Inference Failure](../runbooks/04-gpu-inference-failure.md)
- [Runbook 07 — Anthropic API Failure](../runbooks/07-anthropic-api-failure.md)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

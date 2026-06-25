# Runbook 04 — GPU Inference Failure

**Applies to**: Lamar University IOSME  
**Alert**: `IOSMEGPUDown` or `IOSMEGPUHighMemory`  
**Scope**: GPU node `iosme-gpu-01`, Ollama inference service  
**On-Call Level**: Level 2 (LU DevOps)  
**Estimated Time**: 20–60 minutes  

---

## Step 1 — Determine Impact

GPU inference is used for:
1. **Embedding generation** (semantic search) — falls back to lower-quality keyword search
2. **On-premises LLM inference** (Ollama) — falls back to Anthropic Claude API

Check which features are impacted:

```bash
# Check if Ollama pods are running
kubectl get pods -n iosme-prod -l app=iosme-ollama

# Check IOSME app logs for inference errors
kubectl logs -l app=iosme-app -n iosme-prod --tail=200 | grep -i "ollama\|inference\|gpu"

# Check if Anthropic fallback is active
kubectl logs -l app=iosme-app -n iosme-prod --tail=200 | grep "anthropic"
```

---

## Step 2 — Check GPU Node Health

```bash
# Verify node is Ready
kubectl get node iosme-gpu-01

# Describe for events/taints
kubectl describe node iosme-gpu-01 | grep -A 20 "Events:"

# Check GPU resource availability
kubectl get node iosme-gpu-01 -o json | jq '.status.capacity["nvidia.com/gpu"]'
# Expected: "1"
```

---

## Step 3 — SSH to the GPU Node

```bash
ssh ubuntu@iosme-gpu-01.lamar.edu

# Check NVIDIA driver
nvidia-smi
# If this fails, the driver is not loaded → go to Step 4A

# Check GPU utilization and memory
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
  --format=csv,noheader

# Check NVIDIA container toolkit
ls /usr/bin/nvidia-container-runtime
```

---

## Step 4A — Driver Not Loaded / nvidia-smi Fails

```bash
# Check if driver module is loaded
lsmod | grep nvidia

# Attempt to reload
sudo modprobe nvidia
nvidia-smi

# If still failing, check for driver/DKMS issue
dkms status
sudo apt-get install --reinstall nvidia-driver-545

# Reboot as last resort (coordinate with team first)
sudo reboot
```

---

## Step 4B — OOM / GPU Memory Exhausted

```bash
nvidia-smi
# Look for processes consuming all GPU memory

# Identify the offending container
kubectl get pods -n iosme-prod -o wide | grep iosme-gpu-01

# If Ollama is OOMing:
kubectl delete pod -l app=iosme-ollama -n iosme-prod
# Kubernetes will restart it; Ollama re-loads model on startup (may take 5–10 min)
```

---

## Step 4C — Ollama Pod CrashLoop

```bash
# Check Ollama logs
kubectl logs -l app=iosme-ollama -n iosme-prod --previous

# Common causes:
# - Model file corruption: delete model and re-pull
kubectl exec -it deployment/iosme-ollama -n iosme-prod -- ollama rm llama3.2
kubectl exec -it deployment/iosme-ollama -n iosme-prod -- ollama pull llama3.2

# - PVC full: check storage
kubectl exec -it deployment/iosme-ollama -n iosme-prod -- df -h /root/.ollama
```

---

## Step 5 — Verify NVIDIA Device Plugin

```bash
kubectl get pods -n kube-system -l app=nvdp,app=nvidia-device-plugin-daemonset

# If the device plugin pod is not running:
kubectl rollout restart daemonset/nvdp-nvidia-device-plugin -n kube-system
```

---

## Step 6 — Enable Anthropic Fallback (if GPU repair will take > 30 min)

```bash
# Patch the IOSME config to force Anthropic fallback
kubectl patch configmap iosme-config -n iosme-prod \
  --patch '{"data":{"INFERENCE_PROVIDER":"anthropic"}}'

kubectl rollout restart deployment/iosme-app -n iosme-prod

# Notify the team that local inference is down and Anthropic is active
```

> **Note**: Anthropic API usage incurs cost. Track in the Anthropic console at console.anthropic.com.

---

## Step 7 — Restore GPU Inference

Once GPU node is healthy:

```bash
# Revert to local inference
kubectl patch configmap iosme-config -n iosme-prod \
  --patch '{"data":{"INFERENCE_PROVIDER":"ollama"}}'

kubectl rollout restart deployment/iosme-app -n iosme-prod

# Verify Ollama is responding
kubectl exec -it deployment/iosme-app -n iosme-prod -- \
  curl -s http://iosme-ollama:11434/api/tags | jq '.models[].name'
```

---

## Step 8 — Resolve Alert

Confirm the `IOSMEGPUDown` alert has cleared in Alertmanager. Document root cause in the incident log.

---

## Escalation

| Condition | Action |
|-----------|--------|
| GPU hardware failure | Contact LU IT to replace/repair GPU node |
| NVIDIA driver issue after reinstall | Contact NVIDIA support or LU IT |
| Ollama crashing with unknown error | Escalate to SMEPro (support@smepro.com) |

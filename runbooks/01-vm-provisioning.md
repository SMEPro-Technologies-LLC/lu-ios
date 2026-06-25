# Runbook 01 — VM Provisioning

**Applies to**: Lamar University IOSME Infrastructure  
**Scope**: Provisioning new or replacement VMs in the vSphere environment  
**On-Call Level**: Level 2 (LU DevOps)  
**Estimated Time**: 60–120 minutes  

---

## Prerequisites

- [ ] Access to vCenter (vcenter.lamar.edu) with VM creation permissions
- [ ] SSH access to `iosme-bastion.lamar.edu`
- [ ] Ubuntu 22.04 ISO or VM template available in vSphere
- [ ] DNS entry prepared in LU DNS (contact LU IT Networking)
- [ ] This repository checked out on the bastion host

---

## Step 1 — Gather Information

Determine the role and specs of the new VM from the [VM Inventory](../docs/vm-provisioning.md#vm-inventory).

```bash
# Which VM are you provisioning?
VM_NAME="iosme-worker-03"
VM_ROLE="rke2-agent"
VM_VCPU=16
VM_RAM_GB=64
VM_DISK_GB=500
VM_VLAN=200
```

---

## Step 2 — Provision the VM

### Option A: Terraform (Preferred)

```bash
cd /path/to/iosme-ops/terraform

# Update vsphere-vms.tf to add the new VM definition, then:
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars" -target=vsphere_virtual_machine.${VM_NAME}
```

### Option B: Manual vSphere + Script

```bash
# SSH to bastion
ssh iosme-bastion.lamar.edu

# Run the provisioning script
cd /opt/iosme-ops
./scripts/provision-vm.sh \
  --env prod \
  --host ${VM_NAME} \
  --vcpu ${VM_VCPU} \
  --ram ${VM_RAM_GB} \
  --disk ${VM_DISK_GB}
```

---

## Step 3 — Verify Basic Connectivity

```bash
ping ${VM_NAME}.lamar.edu
ssh ubuntu@${VM_NAME}.lamar.edu "hostname && uptime"
```

---

## Step 4 — Post-Provisioning Hardening

```bash
ssh ubuntu@${VM_NAME}.lamar.edu

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Enable required kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Set kernel parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Verify NTP
timedatectl status
```

---

## Step 5 — Join the Kubernetes Cluster

For a new worker node, follow the [Kubernetes Setup docs](../docs/kubernetes-setup.md#agent-worker-nodes):

```bash
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -

sudo bash -c "cat > /etc/rancher/rke2/config.yaml <<EOF
server: https://iosme-k8s.lamar.edu:9345
token: $(cat /var/lib/rancher/rke2/server/node-token on master-01)
EOF"

sudo systemctl enable rke2-agent
sudo systemctl start rke2-agent
```

---

## Step 6 — Verify Node is Ready

```bash
# From bastion or workstation with kubeconfig
kubectl get nodes -o wide
kubectl describe node ${VM_NAME}
```

Expected status: `Ready`

---

## Step 7 — Update Documentation

- [ ] Update the [VM Inventory table](../docs/vm-provisioning.md#vm-inventory)
- [ ] Record the new node in the CMDB (LU IT ServiceNow)
- [ ] Notify the team in #iosme-ops Slack channel

---

## Rollback

If the VM was provisioned in error:

```bash
# Terraform
terraform destroy -target=vsphere_virtual_machine.${VM_NAME} -var-file="prod.tfvars"

# Or: Delete via vCenter UI
```

Drain and remove the node from Kubernetes first if it was already joined:

```bash
kubectl drain ${VM_NAME} --ignore-daemonsets --delete-emptydir-data
kubectl delete node ${VM_NAME}
```

---

## Escalation

| Condition | Action |
|-----------|--------|
| vCenter unreachable | Contact LU IT Networking |
| DNS entry not resolving | Contact LU IT Networking |
| RKE2 agent fails to join | See [Kubernetes Setup docs](../docs/kubernetes-setup.md) or escalate to Level 3 (SMEPro) |

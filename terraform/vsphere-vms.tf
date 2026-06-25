# vsphere-vms.tf — vSphere VM provisioning for IOSME at Lamar University
#
# Prerequisites:
#   - Terraform >= 1.8
#   - VMware vSphere provider ~> 2.8
#   - GOVC_USERNAME / GOVC_PASSWORD env vars (or vsphere_user/vsphere_password vars)
#   - Ubuntu 22.04 VM template available in vCenter
#
# Usage:
#   terraform init
#   terraform plan -var-file="prod.tfvars"
#   terraform apply -var-file="prod.tfvars"

terraform {
  required_version = ">= 1.8"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.8"
    }
  }

  # Terraform state stored in S3-compatible MinIO
  backend "s3" {
    bucket                      = "terraform-state"
    key                         = "iosme/vsphere-vms/terraform.tfstate"
    region                      = "us-east-1"    # placeholder — MinIO ignores region
    endpoint                    = "http://minio.lamar.edu:9000"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "vsphere_user" {
  description = "vCenter username"
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vCenter password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vCenter FQDN or IP"
  type        = string
  default     = "vcenter.lamar.edu"
}

variable "datacenter" {
  description = "vSphere datacenter name"
  type        = string
  default     = "LU-Datacenter"
}

variable "cluster" {
  description = "vSphere cluster name"
  type        = string
  default     = "LU-Prod-Cluster"
}

variable "resource_pool" {
  description = "vSphere resource pool"
  type        = string
  default     = "IOSME-Prod"
}

variable "datastore_os" {
  description = "Datastore for OS disks"
  type        = string
  default     = "LU-NFS-DS01"
}

variable "datastore_data" {
  description = "Datastore for data/DB disks"
  type        = string
  default     = "LU-SAN-DS01"
}

variable "network_k8s" {
  description = "Network portgroup for Kubernetes nodes (VLAN 200)"
  type        = string
  default     = "LU-VLAN200"
}

variable "network_db" {
  description = "Network portgroup for database nodes (VLAN 201)"
  type        = string
  default     = "LU-VLAN201"
}

variable "network_mgmt" {
  description = "Network portgroup for management (VLAN 100)"
  type        = string
  default     = "LU-VLAN100"
}

variable "vm_template" {
  description = "Ubuntu 22.04 VM template name"
  type        = string
  default     = "ubuntu-2204-template"
}

variable "vm_folder" {
  description = "vSphere VM folder path"
  type        = string
  default     = "IOSME/prod"
}

variable "ssh_public_key" {
  description = "SSH public key to inject via cloud-init"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["10.0.0.10", "8.8.8.8"]
}

variable "domain" {
  description = "DNS domain"
  type        = string
  default     = "lamar.edu"
}

# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = false
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.cluster}/Resources/${var.resource_pool}"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "os" {
  name          = var.datastore_os
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "data" {
  name          = var.datastore_data
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "k8s" {
  name          = var.network_k8s
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "db" {
  name          = var.network_db
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "mgmt" {
  name          = var.network_mgmt
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vm_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ---------------------------------------------------------------------------
# Local variables — VM definitions
# ---------------------------------------------------------------------------

locals {
  vms = {
    "iosme-master-01" = {
      role      = "rke2-server"
      num_cpus  = 8
      memory    = 32768
      disk_gb   = 200
      network   = data.vsphere_network.k8s.id
      ipv4_addr = "10.200.0.11"
    }
    "iosme-master-02" = {
      role      = "rke2-server"
      num_cpus  = 8
      memory    = 32768
      disk_gb   = 200
      network   = data.vsphere_network.k8s.id
      ipv4_addr = "10.200.0.12"
    }
    "iosme-master-03" = {
      role      = "rke2-server"
      num_cpus  = 8
      memory    = 32768
      disk_gb   = 200
      network   = data.vsphere_network.k8s.id
      ipv4_addr = "10.200.0.13"
    }
    "iosme-worker-01" = {
      role      = "rke2-agent"
      num_cpus  = 16
      memory    = 65536
      disk_gb   = 500
      network   = data.vsphere_network.k8s.id
      ipv4_addr = "10.200.0.21"
    }
    "iosme-worker-02" = {
      role      = "rke2-agent"
      num_cpus  = 16
      memory    = 65536
      disk_gb   = 500
      network   = data.vsphere_network.k8s.id
      ipv4_addr = "10.200.0.22"
    }
    "iosme-gpu-01" = {
      role      = "rke2-agent-gpu"
      num_cpus  = 16
      memory    = 131072
      disk_gb   = 500
      network   = data.vsphere_network.k8s.id
      ipv4_addr = "10.200.0.31"
    }
  }

  db_vms = {
    "iosme-db-01" = {
      role      = "postgres-primary"
      num_cpus  = 8
      memory    = 32768
      disk_gb   = 200
      data_gb   = 1000
      network   = data.vsphere_network.db.id
      ipv4_addr = "10.201.0.11"
    }
    "iosme-db-02" = {
      role      = "postgres-replica"
      num_cpus  = 8
      memory    = 32768
      disk_gb   = 200
      data_gb   = 1000
      network   = data.vsphere_network.db.id
      ipv4_addr = "10.201.0.12"
    }
  }
}

# ---------------------------------------------------------------------------
# Kubernetes nodes
# ---------------------------------------------------------------------------

resource "vsphere_virtual_machine" "k8s_nodes" {
  for_each = local.vms

  name             = each.key
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.os.id
  folder           = var.vm_folder

  num_cpus             = each.value.num_cpus
  memory               = each.value.memory
  guest_id             = data.vsphere_virtual_machine.template.guest_id
  scsi_type            = data.vsphere_virtual_machine.template.scsi_type
  hardware_version     = data.vsphere_virtual_machine.template.hardware_version
  firmware             = data.vsphere_virtual_machine.template.firmware

  network_interface {
    network_id   = each.value.network
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "os"
    size             = each.value.disk_gb
    eagerly_scrub    = false
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = each.key
        domain    = var.domain
      }

      network_interface {
        ipv4_address = each.value.ipv4_addr
        ipv4_netmask = 24
      }

      ipv4_gateway    = "10.200.0.1"
      dns_server_list = var.dns_servers
      dns_suffix_list = [var.domain]
    }
  }

  extra_config = {
    "guestinfo.userdata" = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
      hostname       = each.key
      ssh_public_key = var.ssh_public_key
      role           = each.value.role
    }))
    "guestinfo.userdata.encoding" = "base64"
  }

  tags = ["iosme", "prod", each.value.role]

  lifecycle {
    ignore_changes = [
      # Ignore annotation changes (e.g. from vCenter UI notes)
      annotation,
    ]
  }
}

# ---------------------------------------------------------------------------
# Database nodes
# ---------------------------------------------------------------------------

resource "vsphere_virtual_machine" "db_nodes" {
  for_each = local.db_vms

  name             = each.key
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.os.id
  folder           = var.vm_folder

  num_cpus         = each.value.num_cpus
  memory           = each.value.memory
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  hardware_version = data.vsphere_virtual_machine.template.hardware_version
  firmware         = data.vsphere_virtual_machine.template.firmware

  network_interface {
    network_id   = each.value.network
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  # OS disk
  disk {
    label            = "os"
    size             = each.value.disk_gb
    eagerly_scrub    = false
    thin_provisioned = true
    unit_number      = 0
  }

  # Data disk (PostgreSQL data directory)
  disk {
    label            = "pgdata"
    size             = each.value.data_gb
    datastore_id     = data.vsphere_datastore.data.id
    eagerly_scrub    = false
    thin_provisioned = false
    unit_number      = 1
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = each.key
        domain    = var.domain
      }

      network_interface {
        ipv4_address = each.value.ipv4_addr
        ipv4_netmask = 24
      }

      ipv4_gateway    = "10.201.0.1"
      dns_server_list = var.dns_servers
      dns_suffix_list = [var.domain]
    }
  }

  tags = ["iosme", "prod", each.value.role]
}

# ---------------------------------------------------------------------------
# Bastion host
# ---------------------------------------------------------------------------

resource "vsphere_virtual_machine" "bastion" {
  name             = "iosme-bastion"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.os.id
  folder           = var.vm_folder

  num_cpus         = 2
  memory           = 4096
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  hardware_version = data.vsphere_virtual_machine.template.hardware_version
  firmware         = data.vsphere_virtual_machine.template.firmware

  # Management network interface
  network_interface {
    network_id   = data.vsphere_network.mgmt.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  # Kubernetes network interface
  network_interface {
    network_id   = data.vsphere_network.k8s.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "os"
    size             = 50
    eagerly_scrub    = false
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = "iosme-bastion"
        domain    = var.domain
      }

      network_interface {
        ipv4_address = "10.100.0.50"
        ipv4_netmask = 24
      }

      network_interface {
        ipv4_address = "10.200.0.50"
        ipv4_netmask = 24
      }

      ipv4_gateway    = "10.100.0.1"
      dns_server_list = var.dns_servers
      dns_suffix_list = [var.domain]
    }
  }

  tags = ["iosme", "prod", "bastion"]
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "k8s_node_ips" {
  description = "IP addresses of Kubernetes nodes"
  value = {
    for name, vm in vsphere_virtual_machine.k8s_nodes :
    name => vm.default_ip_address
  }
}

output "db_node_ips" {
  description = "IP addresses of database nodes"
  value = {
    for name, vm in vsphere_virtual_machine.db_nodes :
    name => vm.default_ip_address
  }
}

output "bastion_ip" {
  description = "Bastion host management IP"
  value       = vsphere_virtual_machine.bastion.default_ip_address
}

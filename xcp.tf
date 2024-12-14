# OpenTofu Configuration for XCP-NG Hypervisor Deployment

# Provider Configuration
terraform {
  required_providers {
    xenorchestra = {
      source = "vatesfr/xenorchestra"
    }
  }
}

# Network Definitions
resource "xenorchestra_network" "net0_management" {
  name        = "Management Network"
  description = "Network for management endpoints"
}

resource "xenorchestra_network" "net1_lan" {
  name        = "LAN Devices Network"
  description = "Network for local area network devices"
}

resource "xenorchestra_network" "net2_trusted_vms" {
  name        = "Trusted VM Network"
  description = "Isolated network for trusted virtual machines"
}

resource "xenorchestra_network" "net3_exposed" {
  name        = "Internet-Exposed Network"
  description = "Network for VMs directly exposed to the internet"
}

resource "xenorchestra_network" "net4_proxy" {
  name        = "Proxy Network"
  description = "Network for reverse proxy VMs"
}

# VM Definitions
# Xen Orchestrator
resource "xenorchestra_vm" "xen_orchestrator" {
  name        = "xen-orchestrator"
  memory      = 4096  # 4GB RAM
  cpus        = 2
  
  network {
    network_id = xenorchestra_network.net0_management.id
  }

  disk {
    sr_id     = data.xenorchestra_sr.local_storage.id
    name      = "xen-orchestrator-root"
    size      = 50 * 1024 * 1024 * 1024  # 50GB
  }
}

# OpnSense Firewall
resource "xenorchestra_vm" "opnsense_firewall" {
  name        = "opnsense-firewall"
  memory      = 8192  # 8GB RAM
  cpus        = 2

  network {
    network_id = xenorchestra_network.net0_management.id
  }

  network {
    network_id = xenorchestra_network.net1_lan.id
  }

  disk {
    sr_id     = data.xenorchestra_sr.local_storage.id
    name      = "opnsense-boot"
    size      = 32 * 1024 * 1024 * 1024  # 32GB
  }

  # Healthcheck and Auto-Restart Configuration
  lifecycle {
    create_before_destroy = true
  }
}

# Failover/Healthcheck for OpnSense (Secondary VM)
resource "xenorchestra_vm" "opnsense_failover" {
  name        = "opnsense-failover"
  memory      = 8192  # 8GB RAM
  cpus        = 2

  network {
    network_id = xenorchestra_network.net0_management.id
  }

  network {
    network_id = xenorchestra_network.net1_lan.id
  }

  disk {
    sr_id     = data.xenorchestra_sr.local_storage.id
    name      = "opnsense-failover-boot"
    size      = 32 * 1024 * 1024 * 1024  # 32GB
  }

  # Note: Actual failover mechanism would require additional 
  # configuration in Xen Orchestra or external monitoring system
}

# Debian Docker Host
resource "xenorchestra_vm" "docker_host" {
  name        = "debian-docker-host"
  memory      = 16384  # 16GB RAM
  cpus        = 4

  network {
    network_id = xenorchestra_network.net2_trusted_vms.id
  }

  network {
    network_id = xenorchestra_network.net3_exposed.id
  }

  disk {
    sr_id     = data.xenorchestra_sr.local_storage.id
    name      = "docker-host-root"
    size      = 200 * 1024 * 1024 * 1024  # 200GB for Docker storage
  }
}

# Internal LAN Reverse Proxy
resource "xenorchestra_vm" "internal_reverse_proxy" {
  name        = "internal-reverse-proxy"
  memory      = 8192  # 8GB RAM
  cpus        = 2

  network {
    network_id = xenorchestra_network.net1_lan.id
  }

  network {
    network_id = xenorchestra_network.net4_proxy.id
  }

  disk {
    sr_id     = data.xenorchestra_sr.local_storage.id
    name      = "internal-proxy-root"
    size      = 64 * 1024 * 1024 * 1024  # 64GB
  }
}

# Public Internet Reverse Proxy
resource "xenorchestra_vm" "public_reverse_proxy" {
  name        = "public-reverse-proxy"
  memory      = 8192  # 8GB RAM
  cpus        = 2

  network {
    network_id = xenorchestra_network.net3_exposed.id
  }

  network {
    network_id = xenorchestra_network.net4_proxy.id
  }

  disk {
    sr_id     = data.xenorchestra_sr.local_storage.id
    name      = "public-proxy-root"
    size      = 64 * 1024 * 1024 * 1024  # 64GB
  }
}

# Data sources to reference existing resources
data "xenorchestra_sr" "local_storage" {
  # Assumes a local storage SR exists on the XCP-NG host
  name_label = "Local storage"
}

# Optional: VM Group for Management
resource "xenorchestra_group" "management_vms" {
  name        = "Management VMs"
  vms         = [
    xenorchestra_vm.xen_orchestrator.id,
    xenorchestra_vm.opnsense_firewall.id,
    xenorchestra_vm.opnsense_failover.id,
    xenorchestra_vm.internal_reverse_proxy.id,
    xenorchestra_vm.public_reverse_proxy.id
  ]
}

# Optional: Backup and Snapshot Configuration
resource "xenorchestra_snapshot_schedule" "daily_snapshots" {
  name        = "Daily VM Snapshots"
  scheduling  = "0 0 * * *"  # Daily at midnight
  vms         = [
    xenorchestra_vm.xen_orchestrator.id,
    xenorchestra_vm.opnsense_firewall.id,
    xenorchestra_vm.docker_host.id
  ]
  
  retention {
    number = 7  # Keep 7 most recent snapshots
  }
}

# Note: Actual deployment requires:
# 1. Configured Xen Orchestra provider credentials
# 2. Existing XCP-NG hypervisor infrastructure
# 3. Proper network switch configuration
# 4. Additional security and HA configurations

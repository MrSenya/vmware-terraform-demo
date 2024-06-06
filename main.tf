# Create a catalog, opload photon ovs, create a new vApp
# Photon OVA URL: https://packages.vmware.com/photon/3.0/GA/ova/photon-hw11-3.0-26156e2.ova

# Catalog
resource "vcd_catalog" "demo_catalog" {
  name        = "OperatingSystems"
  description = "Demo OS templates"

  delete_force     = "true"
  delete_recursive = "true"
}

# Linux OVA
resource "vcd_catalog_item" "demo_linux" {
  catalog     = vcd_catalog.demo_catalog.name
  name        = "photon-hw11"
  description = "Linux VM photon-hw11"

  ova_path = "/path/to/file.ova"

  upload_piece_size    = 10
  show_upload_progress = true
}

# Note: all resources are created inside a NSX-T VDC

data "vcd_nsxt_edgegateway" "existing" {
  name = "NAME_YOUR_EDGEGATEWAY"
}

resource "vcd_network_routed_v2" "net_r_v2" {
  name            = "net_r_v2"
  edge_gateway_id = data.vcd_nsxt_edgegateway.existing.id
  gateway         = "10.10.102.1"
  prefix_length   = 24

  static_ip_pool {
    start_address = "10.10.102.2"
    end_address   = "10.10.102.200"
  }
}

resource "vcd_network_isolated_v2" "net_i_v2" {
  name = "net_i_v2"

  gateway       = "110.10.102.1"
  prefix_length = 26

  static_ip_pool {
    start_address = "110.10.102.2"
    end_address   = "110.10.102.20"
  }
}

resource "vcd_nsxt_network_dhcp" "net_r_dhcp" {
  org_network_id = vcd_network_routed_v2.net_r_v2.id

  pool {
    start_address = "10.10.102.210"
    end_address   = "10.10.102.220"
  }

  pool {
    start_address = "10.10.102.230"
    end_address   = "10.10.102.240"
  }
}

# vApp
resource "vcd_vapp" "demo_vapp" {
  name        = "demo-vapp"
  description = "Demo vApp vCloud"
}

# Add roted network to vApp
resource "vcd_vapp_org_network" "routed-network" {
  vapp_name        = vcd_vapp.demo_vapp.name
  org_network_name = vcd_network_routed_v2.net_r_v2.name
}

# Add isolated network to vApp
resource "vcd_vapp_org_network" "isolated-network" {
  vapp_name        = vcd_vapp.demo_vapp.name
  org_network_name = vcd_network_isolated_v2.net_i_v2.name
}

#Template item
data "vcd_catalog_vapp_template" "photon-os" {
  catalog_id = vcd_catalog.demo_catalog.id
  name       = "photon-hw11"

  depends_on = [vcd_catalog_item.demo_linux]
}

# Define the static IP addresses in a variable
variable "static_ips" {
  type    = list(string)
  default = ["10.10.102.161", "10.10.102.162", "10.10.102.163"]
}

resource "vcd_vapp_vm" "standaloneVm" {
  vapp_name        = vcd_vapp.demo_vapp.name
  name             = "standaloneVm-${count.index}"
  computer_name    = "standaloneVm-unique-${count.index}"
  vapp_template_id = data.vcd_catalog_vapp_template.photon-os.id
  description      = "test standalone VM"
  memory           = 2048
  cpus             = 2
  cpu_cores        = 1

  count = 3

  network_dhcp_wait_seconds = 10

  network {
    type               = "org"
    name               = vcd_network_routed_v2.net_r_v2.name
    ip_allocation_mode = "MANUAL"
    ip                 = element(var.static_ips, count.index)
  }

  network {
    type               = "org"
    name               = vcd_network_routed_v2.net_r_v2.name
    ip_allocation_mode = "DHCP"
  }

  network {
    type               = "org"
    name               = vcd_network_routed_v2.net_r_v2.name
    ip_allocation_mode = "POOL"
  }

  network {
    type               = "org"
    name               = vcd_network_isolated_v2.net_i_v2.name
    ip_allocation_mode = "POOL"
  }

}

# Terraform Configuration for VMware vCloud Director

## Overview

This Terraform configuration file sets up a VMware vCloud Director environment. It includes the creation of a catalog, uploading an OVA template, setting up routed and isolated networks, configuring DHCP, and deploying a vApp with VMs.

## Prerequisites

- Terraform installed on your machine.
- Access to a VMware vCloud Director environment.
- A valid OVA file to upload.

## Configuration Variables

Ensure you replace the placeholder values with your actual credentials and details.

```hcl
vcd_user                 = "YOUR_USERNAME"
vcd_pass                 = "YOUR_PASSWORD"
vcd_url                  = "YOUR_URL_FOR_vCloud_Director"
vcd_max_retry_timeout    = "60"
vcd_allow_unverified_ssl = "true"
org_name                 = "YOUR_ORG_NAME"
org_vdc                  = "YOUR_ORG_VDC_NAME"
```

## Terraform Variables

The following variables are defined for use within the configuration:

```hcl
variable "vcd_user" {
  description = "vCloud user"
}

variable "vcd_pass" {
  description = "vCloud password"
}

variable "vcd_allow_unverified_ssl" {
  default = true
}

variable "vcd_url" {
  description = "vCloud URL"
}

variable "org_name" {
  description = "vCloud Organization"
}

variable "org_vdc" {
  description = "vCloud Data center (VDC)"
}

variable "vcd_max_retry_timeout" {
  default = 120
}

```

## Provider Configuration

This section specifies the required provider and its version:

```hcl
terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "3.12.1"
    }
  }
}

provider "vcd" {
  url      = var.vcd_url
  user     = var.vcd_user
  password = var.vcd_pass
  org      = var.org_name
  vdc      = var.org_vdc

  max_retry_timeout    = var.vcd_max_retry_timeout
  allow_unverified_ssl = var.vcd_allow_unverified_ssl

  logging = "true"
}

```

# Resources

## Catalog

Create a catalog to store VM templates:

```hcl
resource "vcd_catalog" "demo_catalog" {
  name        = "OperatingSystems"
  description = "Demo OS templates"

  delete_force     = "true"
  delete_recursive = "true"
}

```

## Catalog Item

Upload the OVA file to the catalog:

```hcl
resource "vcd_catalog_item" "demo_linux" {
  catalog     = vcd_catalog.demo_catalog.name
  name        = "photon-hw11"
  description = "Linux VM photon-hw11"

  ova_path = "/path/to/file.ova"

  upload_piece_size    = 10
  show_upload_progress = true
}

```

## Networks

Create routed and isolated networks, and configure DHCP:

```hcl
data "vcd_nsxt_edgegateway" "existing" {
  name = "NAME_YOUR_EDGEGATEWAY"
}

resource "vcd_network_routed_v2" "net_r_v2" {
  name = "net_r_v2"
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

```

## vApp

Create a vApp and add networks:

```hcl
resource "vcd_vapp" "demo_vapp" {
  name        = "demo-vapp"
  description = "Demo vApp vCloud"
}

resource "vcd_vapp_org_network" "routed-network" {
  vapp_name        = vcd_vapp.demo_vapp.name
  org_network_name = vcd_network_routed_v2.net_r_v2.name
}

resource "vcd_vapp_org_network" "isolated-network" {
  vapp_name        = vcd_vapp.demo_vapp.name
  org_network_name = vcd_network_isolated_v2.net_i_v2.name
}

```

## VMs

Create VMs within the vApp and attach them to networks:

```hcl
data "vcd_catalog_vapp_template" "photon-os" {
  catalog_id = vcd_catalog.demo_catalog.id
  name       = "photon-hw11"

  depends_on = [vcd_catalog_item.demo_linux]
}

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

```

# Running the Configuration

1. Initialize Terraform:

```sh
terraform init
```

2. Review the plan:

```sh
terraform plan
```

3. Apply the configuration:

```sh
terraform apply
```

# Notes

- Ensure the OVA file path in vcd_catalog_item.demo_linux is correctly set to the location of your OVA file.
- The network configurations are set up for both routed and isolated networks. Adjust the gateway and IP ranges as needed.
- The static_ips variable holds the static IP addresses for the VMs. Adjust these as necessary.

# Conclusion

This configuration provides a comprehensive setup for deploying a vApp in a vCloud Director environment, including catalog creation, network setup, and VM deployment. Modify the variables and resources as needed to fit your specific environment and requirements.
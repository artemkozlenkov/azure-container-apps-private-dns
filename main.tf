locals {
  name     = "cap-test-1"
  location = "westeurope"
}
resource "azurerm_resource_group" "this" {
  location = "westeurope"
  name     = "rg-cap-test"
}
resource "azurerm_virtual_network" "this" {
  address_space       = ["10.2.0.0/27"]
  location            = local.location
  name                = "vnet-cap-test"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_container_app" "res-1" {
  container_app_environment_id = azurerm_container_app_environment.res-2.id
  name                         = local.name
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      cpu    = 0.25
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      memory = "0.5Gi"
      name   = "simple-hello-world-container"
    }
  }

  workload_profile_name = "dedicated4"
}
resource "azurerm_subnet" "this" {
  address_prefixes     = ["10.2.0.0/27"]
  name                 = "default"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  delegation {
    name = "Microsoft.App/environments"

    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
      name = "Microsoft.App/environments"
    }
  }
}

resource "azurerm_container_app_environment" "res-2" {
  location                       = azurerm_resource_group.this.location
  name                           = "apenv-${local.name}"
  resource_group_name            = azurerm_resource_group.this.name
  infrastructure_subnet_id       = azurerm_subnet.this.id
  internal_load_balancer_enabled = true
  workload_profile {
    name                  = "dedicated4"
    workload_profile_type = "D4"
    maximum_count         = 1
    minimum_count         = 0
  }
  depends_on = [azurerm_subnet.this]
}

resource "azurerm_private_dns_zone" "this" {
  name                = azurerm_container_app_environment.res-2.default_domain
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "vnetlink-vnet-cap-test"
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = azurerm_virtual_network.this.id
}

resource "azurerm_private_dns_a_record" "this" {
  name                = azurerm_container_app.res-1.name
  records             = [azurerm_container_app_environment.res-2.static_ip_address]
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 60
  zone_name           = azurerm_private_dns_zone.this.name
}

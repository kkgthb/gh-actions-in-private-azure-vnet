# "Hello world" query I can remove later
data "azurerm_client_config" "current_azrm_context" {}

# Azure resource group to hold it all
resource "azurerm_resource_group" "my_resource_group" {
  name     = "${var.workload_nickname}-rg-demo"
  location = "centralus"
}

# Explicitly register the GitHub.Network resource provider so that the
# GitHub Network Settings resource below can be provisioned even when
# resource_provider_registrations = "none" is set on the azurerm provider.
resource "azurerm_resource_provider_registration" "github_network" {
  name = "GitHub.Network"
}

# ---------------------------------------------------------------------------
# Network Security Group
# Purpose:  override Microsoft's built-in default security rules so that
#   runner subnets have NO inbound access and only port-443 outbound access.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "my_nsg" {
  name                = "${var.workload_nickname}-nsg-demo"
  location            = azurerm_resource_group.my_resource_group.location
  resource_group_name = azurerm_resource_group.my_resource_group.name
}

# Inbound: deny all traffic sourced from within the virtual network.
# Overrides Microsoft's default "AllowVnetInBound" rule (priority 65000).
resource "azurerm_network_security_rule" "deny_vnet_inbound" {
  name                        = "DenyVnetInBound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.my_resource_group.name
  network_security_group_name = azurerm_network_security_group.my_nsg.name
}

# Inbound: deny probes from the Azure Load Balancer.
# Overrides Microsoft's default "AllowAzureLoadBalancerInBound" rule (priority 65001).
resource "azurerm_network_security_rule" "deny_azure_lb_inbound" {
  name                        = "DenyAzureLoadBalancerInBound"
  priority                    = 4001
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "0.0.0.0/0"
  resource_group_name         = azurerm_resource_group.my_resource_group.name
  network_security_group_name = azurerm_network_security_group.my_nsg.name
}

# Outbound: allow HTTPS (443) to the Internet.
# Must be evaluated BEFORE the two Deny rules below (lower priority number = higher priority).
# Runners need port 443 to reach GitHub APIs and Azure endpoints.
resource "azurerm_network_security_rule" "allow_port_443_outbound" {
  name                        = "AllowPort443InternetOutbound"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.my_resource_group.name
  network_security_group_name = azurerm_network_security_group.my_nsg.name
}

# Outbound: prevent runners from talking to each other across subnets.
# Overrides Microsoft's default "AllowVnetOutBound" rule (priority 65000).
# NOTE:  if VNET peering to other private networks is required, this rule may
#        need to be removed and those findings documented.
resource "azurerm_network_security_rule" "deny_vnet_outbound" {
  name                        = "DenyVnetOutBound"
  priority                    = 4010
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.my_resource_group.name
  network_security_group_name = azurerm_network_security_group.my_nsg.name
}

# Outbound: deny all remaining Internet-bound traffic (everything except port 443,
# which was already allowed above).
# Overrides Microsoft's default "AllowInternetOutBound" rule (priority 65001).
resource "azurerm_network_security_rule" "deny_internet_outbound" {
  name                        = "DenyInternetOutbound"
  priority                    = 4020
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.my_resource_group.name
  network_security_group_name = azurerm_network_security_group.my_nsg.name
}

# ---------------------------------------------------------------------------
# Virtual Network
# A /28 gives 16 addresses (14 usable) -- exactly sized for the single /28
# subnet below, keeping the demo footprint as small as possible.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "my_vnet" {
  name                = "${var.workload_nickname}-vnet-demo"
  location            = azurerm_resource_group.my_resource_group.location
  resource_group_name = azurerm_resource_group.my_resource_group.name
  address_space       = ["10.0.0.0/28"]
}

# ---------------------------------------------------------------------------
# Subnet
# One subnet per GitHub.Network/networkSettings resource.
# A /28 yields 14 usable IPs -- plenty for a proof-of-concept runner pool.
# Delegated to GitHub.Network/networkSettings so Azure knows this subnet is
# reserved for GitHub-hosted runner VMs.
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "my_subnet" {
  name                 = "${var.workload_nickname}-snet-demo"
  resource_group_name  = azurerm_resource_group.my_resource_group.name
  virtual_network_name = azurerm_virtual_network.my_vnet.name
  address_prefixes     = ["10.0.0.0/28"]

  delegation {
    name = "github-network-settings-delegation"
    service_delegation {
      name    = "GitHub.Network/networkSettings"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Attach the NSG to the subnet.
resource "azurerm_subnet_network_security_group_association" "my_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.my_subnet.id
  network_security_group_id = azurerm_network_security_group.my_nsg.id
}

# ---------------------------------------------------------------------------
# GitHub Organization data (used as businessId below)
# ---------------------------------------------------------------------------
data "github_organization" "gh_org_details" {
  name = var.gh_org_name
}

# ---------------------------------------------------------------------------
# GitHub Network Settings Azure resource  (type: GitHub.Network/networkSettings)
# This resource registers the subnet with GitHub so that GitHub-hosted runner
# VMs are provisioned inside the VNET above.
# One networkSettings resource per subnet -- do not share subnets.
# Uses the azapi provider because this resource type is not yet surfaced in
# the azurerm provider.
# ---------------------------------------------------------------------------
resource "azapi_resource" "my_ghns" {
  type      = "GitHub.Network/networkSettings@2024-04-02"
  name      = "${var.workload_nickname}-ghns-demo"
  parent_id = azurerm_resource_group.my_resource_group.id
  location  = azurerm_resource_group.my_resource_group.location
  body = {
    properties = {
      subnetId   = azurerm_subnet.my_subnet.id
      businessId = data.github_organization.gh_org_details.id
    }
  }
  response_export_values = ["tags.GitHubId"]
  depends_on = [azurerm_resource_provider_registration.github_network]
  # GitHub.Network/networkSettings does not return its resource identity in
  # update (PUT) responses, which causes azapi to error on any in-place change.
  # Azure also stamps a GitHubId tag on this resource after creation, and the
  # exported output values are re-computed on every plan -- both of which
  # trigger spurious updates.  Treat the resource as create/destroy-only.
  lifecycle {
    ignore_changes = all
  }
}

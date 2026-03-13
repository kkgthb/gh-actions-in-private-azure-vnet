# "Hello world" query I can remove later
data "azurerm_client_config" "current_azrm_context" {}

# Azure resource group to hold it all
resource "azurerm_resource_group" "my_resource_group" {
  name     = "${var.workload_nickname}-rg-demo"
  location = "centralus"
}

# TODO:  an Azure network security group.
# Purpose:  to control inbound/outbound traffic to/from any subnets referencing this NSG.
# I want to override several of Microsoft's built-in 
# (https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview#default-security-rules)
# default security rules, in this case.
# I want each subnet to have no inbound access, and only port 443 outbound access.

# TODO:  an Azure network security group security rule 
# (waiddaminute, is this redundant to below?)
# Name:  (LLM can choose)
# Access:  Deny
# Protocol:  * (any)
# Source:  VirtualNetwork (all ports, 0-65535)
# Destination:  VirtualNetwork (all ports, 0-65535)
# Priority:  A much smaller integer (higher priority) than 65000, which is the number at which Microsoft's default security rules in need of override seem to start.

# TODO:  an Azure network security group security rule
# Name:  DenyAzureLoadBalancerInBound
# Access:  Deny
# Protocol:  * (any)
# Source:  AzureLoadBalancer (all ports, 0-65535)
# Destination:  0.0.0.0/0 (all ports, 0-65535)
# Priority:  A much smaller integer (higher priority) than 65000, which is the number at which Microsoft's default security rules in need of override seem to start.

# TODO:  an Azure network security group security rule
# (waiddaminute, is this redundant to above?)
# Name:  DenyVnetOutBound
# Access:  Deny
# Protocol:  * (any)
# Source:  VirtualNetwork (all ports, 0-65535)
# Destination:  VirtualNetwork (all ports, 0-65535)
# Priority:  A much smaller integer (higher priority) than 65000, which is the number at which Microsoft's default security rules in need of override seem to start.
# Notes:  GitHub Actions runners will each be placed into their own Subnet, 
#  and they have no business talking to each other, so this helps locks that down even if, for management efficiency, 
#  they end up placed within the same Azure VNET.  
#  However, it is unclear if this NSG security rule override will break GitHub Actions runners' ability to reach Azure resources within other VNETs
#  to which they might be peered.
#  This resource might need to be destroyed, and notes taken, if it causes such unintended blocks.  But try with it in place, first, and see what happens.

# TODO:  an Azure network security group security rule
# Name:  DenyInternetOutbound
# Access:  Deny
# Protocol:  * (any)
# Source:  0.0.0.0/0 (all ports, 0-65535)
# Destination:  Internet (all ports, 0-65535)
# Priority:  A smaller integer (higher priority) than that of "DenyInternetOutbound" above.
#   (waiddaminute, this one is DenyInternetOutbound.  Where did I make a typo in my specs?  Sigh)

# TODO:  an Azure network security group security rule
# Name:  AllowPort443InternetOutbound
# Access:  Allow
# Protocol:  TCP
# Port:  443
# Source:  0.0.0.0/0
# Destination:  Internet
# Priority:  A bigger integer (lower priority) than the related NSG security rules below.  A much smaller integer (higher priority) than 65000, 
#   which is the number at which Microsoft's default security rules in need of override seem to start.
#   (maybe this is the one that should've said "smaller integer / higher priority" than "DenyInternetOutbound above"??)
# Notes (no idea if all borked up, too):  See additional NSG security rules below for the ports to reopen.  They will need even smaller integers than this one.

# TODO:  an Azure virtual network (VNET)
# Notes:  To help network-isolate the "runner" VM.
#   Of course, in the real world, 
#   this VNET would need a line of sight into whatever private network it is meant to facilitate continuous deployment into, 
#   lest the CI/CD job fail at a network level.
#   But that is beyond the scope of this demo, so don't worry about it for now in this particular tutorial repo.
# IP count to request from IP address provider (or make up):
#   an appropriate CIDR block to accommodate expected concurrency from GitHub Actions managed runners associated with the subnets within this VNET.
#   1 IP per "runner" VM that might concurrently need an IP address from the subnet below.
#   Times the number of subnets that end up in this VNET, if it expands to include more than one subnet.
#   See notes below under subnet -- to start, a relatively small space like a /25-/28 should be plenty.
#   "To determine the appropriate subnet IP address range, we recommend adding a 30% buffer to the maximum job concurrency you anticipate. 
#    For instance, if your network configuration's runners are set to a maximum job concurrency of 300, 
#    it's recommended to utilize a subnet IP address range that can accommodate at least 390 runners. 
#    This buffer helps ensure that your network can handle unexpected increases in VM needs to meet job concurrency without running out of IP addresses."
#  - https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization#configuring-your-azure-resources

# TODO:  An Azure subnet
# Delegation:  "GitHub.Network/networkSettings"
# Network Security Group ID:  see network security group above
# Notes:  Microsoft will use an IP address from within this subnet when provisioning a "runner" VM.
# IP count to request from IP address provider (or make up):
#   an appropriate CIDR block to accommodate expected concurrency from GitHub Actions managed runners associated with this subnet.  
#   1 IP per "runner" VM that might concurrently need an IP address from this subnet, which should have exactly one and only one "GitHub.Network/networkSettings" 
#   Azure resource within it.  However, any given "GitHub.Network/networkSettings" might offer more than 1 concurrent "runner," 
#   so more than 1 IP address per subnet might be needed.  
#   To start, for a proof of concept, a /28 (14 usable IP addresses) per subnet (that is, per "GitHub.Network/networkSettings") should be plenty.

data "github_organization" "gh_org_details" {
  name = var.gh_org_name
}

# TODO:  A "GitHub Network Settings" Azure resource.
# Subnet ID:  (see subnet above)
# Business ID:  ${data.github_organization.gh_org_details.id}
# Note:  If no such resource has ever been provisioned before within this Azure subscription, 
#   an Azure resource provider might need to be registered first, lest provisioning this resource type fail.
# Note:  Please do not place more than one of these at a time within a given subnet.  Please give each one its own subnet.

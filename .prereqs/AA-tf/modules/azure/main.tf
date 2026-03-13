# "Hello world" query I can remove later
data "azurerm_client_config" "current_azrm_context" {}

# Azure resource group to hold it all
resource "azurerm_resource_group" "my_resource_group" {
  name     = "${var.workload_nickname}-rg-demo"
  location = "centralus"
}
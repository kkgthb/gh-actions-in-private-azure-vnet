module "azure" {
  source = "./modules/azure"
  providers = {
    azurerm = azurerm.demo
    azapi   = azapi.demo
    github  = github.demo
  }
  workload_nickname = var.workload_nickname
  gh_org_name       = var.gh_org_name
}

module "github_org_config" {
  depends_on = [ module.azure ]
  source = "./modules/github/orgconfig"
  providers = {
    github = github.demo
  }
  workload_nickname = var.workload_nickname
  gh_org_name       = var.gh_org_name
  az_ghns_ghid      = module.azure.az_ghns_ghid
}

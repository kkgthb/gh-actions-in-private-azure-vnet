# "Hello world" query I can remove later
data "github_organization" "my_gh_org" {
  name = var.gh_org_name
}

# Make sure my network config exists
resource "null_resource" "my_gh_network_config" {
  # Fire off this resource block if anything about any of these details changes
  triggers = {
    gh_org_name            = var.gh_org_name
    gh_network_config_name = local.my_gh_network_config_name
    az_ghns_ghid           = var.az_ghns_ghid
  }
  # Upon CREATE:  if (configname) does not yet exist, HTTPS POST to create it.
  provisioner "local-exec" {
    when        = create
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
    $all_nc = (gh api /orgs/${self.triggers.gh_org_name}/settings/network-configurations) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $existing_nc_id = ($all_nc.network_configurations | Where-Object { $_.name -eq '${self.triggers.gh_network_config_name}' } | Select-Object -First 1 -ExpandProperty id)
    if (-not $existing_nc_id) {
      gh api --method POST /orgs/${self.triggers.gh_org_name}/settings/network-configurations `
        -f name="${self.triggers.gh_network_config_name}" `
        -f compute_service="actions" `
        -f "network_settings_ids[]=${self.triggers.az_ghns_ghid}"
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
      Write-Output "Created network configuration '${self.triggers.gh_network_config_name}'."
    }
     else {
      Write-Output "Network configuration '${self.triggers.gh_network_config_name}' already exists (id: $existing_nc_id), skipping creation."
    }
    EOT
  }
  # Upon DESTROY:  if (configname) exists, HTTPS DELETE to destroy it.
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
    $all_nc = (gh api /orgs/${self.triggers.gh_org_name}/settings/network-configurations) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $existing_nc_id = ($all_nc.network_configurations | Where-Object { $_.name -eq '${self.triggers.gh_network_config_name}' } | Select-Object -First 1 -ExpandProperty id)
    if ($existing_nc_id) {
      gh api --method DELETE "/orgs/${self.triggers.gh_org_name}/settings/network-configurations/$existing_nc_id"
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
      Write-Output "Deleted network configuration '${self.triggers.gh_network_config_name}' (id: $existing_nc_id)."
    } else {
      Write-Output "Network configuration '${self.triggers.gh_network_config_name}' not found, nothing to delete."
    }
    EOT
  }
}

# "Hello world, how many network configurations are there so far?" query I can remove later (current answer:  0)
data "external" "gh_network_config_count" {
  depends_on = [null_resource.my_gh_network_config]
  program = [
    "pwsh",
    "${path.module}/get_network_config_count.ps1",
    "-theorg", var.gh_org_name
  ]
}


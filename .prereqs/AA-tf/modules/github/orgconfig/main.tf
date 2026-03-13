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
    # az_ghns_ghid           = var.az_ghns_ghid
  }
  # Upon CREATE:  if (configname) does not yet exist, HTTPS POST to create it.
  provisioner "local-exec" {
    when        = create
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
    # Hello world placeholder
    Write-Host "Running GH API idempotent-create for ${self.triggers.gh_org_name}"
    gh api /orgs/${self.triggers.gh_org_name}/settings/network-configurations
    EOT
  }
  # Upon DESTROY:  if (configname) exists, HTTPS DELETE to destroy it.
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
    # Hello world placeholder
    Write-Host "Running GH API idempotent-destroy for ${self.triggers.gh_org_name}"
    gh api /orgs/${self.triggers.gh_org_name}/settings/network-configurations
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


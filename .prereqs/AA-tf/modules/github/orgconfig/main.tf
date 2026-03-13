# "Hello world" query I can remove later
data "github_organization" "my_gh_org" {
  name = var.gh_org_name
}

# Make sure my network config exists
resource "null_resource" "my_gh_network_config" {
  depends_on = [var.az_ghns_ghid]
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

# Look up the ID of the network config we just created so we can assign it to the runner group
data "external" "gh_network_config_id" {
  depends_on = [null_resource.my_gh_network_config]
  program = [
    "pwsh",
    "${path.module}/get_network_config_id.ps1",
    "-theorg", var.gh_org_name,
    "-thename", local.my_gh_network_config_name
  ]
}

# Create a runner group
resource "github_actions_runner_group" "my_gh_runner_group" {
  depends_on                 = [null_resource.my_gh_network_config]
  name                       = local.my_gh_runner_group_name
  allows_public_repositories = false
  visibility                 = "all" # TODO:  tighten up this security authZ grant to selected repos once I actually have any
}

# Assign the network configuration to the runner group
# (github_actions_runner_group has no network_configuration_id argument in the Terraform provider)
resource "null_resource" "my_gh_runner_group_network_config" {
  depends_on = [github_actions_runner_group.my_gh_runner_group, data.external.gh_network_config_id]
  triggers = {
    runner_group_id = github_actions_runner_group.my_gh_runner_group.id
    nc_id           = data.external.gh_network_config_id.result["nc_id"]
    gh_org_name     = var.gh_org_name
  }
  provisioner "local-exec" {
    when        = create
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
    gh api --method PATCH /orgs/${self.triggers.gh_org_name}/actions/runner-groups/${self.triggers.runner_group_id} `
      -f network_configuration_id="${self.triggers.nc_id}"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Output "Assigned network configuration '${self.triggers.nc_id}' to runner group '${self.triggers.runner_group_id}'."
    EOT
  }
}

# Create a runner
resource "github_actions_hosted_runner" "my_gh_runner" {
  depends_on      = [null_resource.my_gh_network_config, null_resource.my_gh_runner_group_network_config]
  name            = local.my_gh_runner_name
  runner_group_id = github_actions_runner_group.my_gh_runner_group.id
  size            = "2-core"
  image {
    source = "github"
    id     = "2306" # 2306 is ubuntu_latest as of 2026-03-13
  }
}

# A quick check to witness the runner hopefully
resource "github_repository" "my_gh_repo" {
  depends_on = [github_actions_hosted_runner.my_gh_runner]
  name       = local.my_gh_repo_name
  visibility = "internal"
  auto_init  = true
}
resource "github_repository_file" "my_gha_yaml" {
  depends_on = [github_actions_hosted_runner.my_gh_runner, github_repository.my_gh_repo]
  repository = github_repository.my_gh_repo.id
  file       = ".github/workflows/demo_workflow.yml"
  content    = <<EOF
name: "Demo GitHub Actions Workflow"
on:
  workflow_dispatch:
  push:
    branches:
      - '**'
jobs:
  job_1:
    runs-on: ['${local.my_gh_runner_name}']
    name: 'First job.  Note it can run in parallel to other jobs'
    steps:
      - id: 'step_a_within_job_1'
        name: 'Write "Hello, World"'
        run: 'echo "Hello, World.  We are starting our first job"'
EOF
}

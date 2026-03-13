# "Hello world" query I can remove later
data "github_organization" "my_gh_org" {
  name = var.gh_org_name
}

# "Hello world, how many network configurations are there so far?" query I can remove later (current answer:  0)
data "external" "gh_network_config_count" {
  program = [
    "pwsh",
    "${path.module}/get_network_config_count.ps1",
    "-theorg", var.gh_org_name
  ]
}
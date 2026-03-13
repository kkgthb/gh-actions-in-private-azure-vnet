# The network settings ID returned by the GitHub.Network/networkSettings ARM
# resource.  Passed to the GitHub provider to link the runner network
# configuration on the GitHub side.
output "az_ghns_ghid" {
  value = azapi_resource.my_ghns.output.tags.GitHubId
}

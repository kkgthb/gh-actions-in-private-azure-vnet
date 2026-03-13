variable "workload_nickname" {
  type = string
}
variable "gh_org_name" {
  type = string
}
variable "az_ghns_ghid" {
  type        = string
  description = "'GitHub ID' of the applicable 'GitHub.Network/networkSettings'-typed Azure resource"
  nullable    = false
  validation {
    condition     = length(var.az_ghns_ghid) > 0
    error_message = "The az_ghns_ghid variable must not be an empty string."
  }
}

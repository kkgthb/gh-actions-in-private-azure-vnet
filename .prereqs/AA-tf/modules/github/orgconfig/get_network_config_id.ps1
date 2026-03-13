param(
    [string]$theorg,
    [string]$thename
)
try {
    $theresult = gh api "/orgs/$theorg/settings/network-configurations" | ConvertFrom-Json
    $nc_id = ($theresult.network_configurations | Where-Object { $_.name -eq $thename } | Select-Object -First 1 -ExpandProperty id)
    if (-not $nc_id) { $nc_id = "" }
    Write-Output "{ `"nc_id`": `"$nc_id`" }"
}
catch {
    Write-Output "{ `"nc_id`": `"`" }"
}

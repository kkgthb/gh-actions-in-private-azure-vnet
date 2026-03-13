param(
    [string]$theorg
)
try {
    $theresult = gh api "/orgs/$theorg/settings/network-configurations" | ConvertFrom-Json
    $thecount = $theresult.total_count
    # Output as JSON with string value
    Write-Output "{ `"total_count`": `"$thecount`" }"
}
catch {
    Write-Output "{ `"total_count`": `"-1`" }"
}
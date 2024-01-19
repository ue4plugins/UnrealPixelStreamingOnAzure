Param (
  [String] $resourceGroup
)

$subscriptionId = az account show --query "id"
$randomString = az tag list --resource-id /subscriptions/$subscriptionId/resourcegroups/$resourceGroup --query "properties.tags.RandomString"

if ($randomString -eq $null) {
    Write-Host "No random string found"
}

$config = (Get-Content  "../arm/createuiDefinition.parameters.json" -Raw) | ConvertFrom-Json
$dnsConfig = $config.security_dnsConfig
$dnsCheck = $false
if($dnsConfig.value -ne $null -And $dnsConfig.value.id -ne $null)
{
    $dnsConfigRg = $dnsConfig.value.id.Split('/')[4]
    $dnsConfigZone = $dnsConfig.value.name
    $dnsCheck = $true
}

$dns = $null
if ($randomString) {
    $rgs = az group list --tag RandomString=$randomString --query "[].name" | ConvertFrom-Json
    if($dnsCheck)
    {
        $dns = az network dns record-set list -g $dnsConfigRg -z $dnsConfigZone --query "[?metadata.randomString=='$randomString']" | ConvertFrom-Json
    }
}


Write-Host "Action to be executed:"
foreach($rg in $rgs) {
    Write-Host "- Delete RG $rg"
}
foreach($dnszone in $dns) {
    Write-Host ("- Delete DNS Zone "+$dnszone.fqdn)
}

Write-Host ""

foreach($rg in $rgs) {
    az group delete -n $rg --no-wait -y
}
Write-Host ($rgs.Count.ToString() + " RGs deleted asynchronously. It will take a few minutes to complete.")
foreach($dnszone in $dns) {
    if($dnszone.type -eq 'Microsoft.Network/dnszones/A')
    {
        az network dns record-set a delete -n $dnszone.name -g $dnsConfigRg -z $dnsConfigZone -y
    }
    elseif($dnszone.type -eq 'Microsoft.Network/dnszones/CNAME') {
        az network dns record-set cname delete -n $dnszone.name -g $dnsConfigRg -z $dnsConfigZone -y
    }
}
Write-Host ($dns.Count.ToString() + " DNS Zones deleted.")

Param (
  [String] $resourceGroup,
  [String] $prebuiltReleaseFolder,
  [Boolean] $buildDashboard = $true
)

function Get-StorageAccountName {
    param (
        [String] $connectionString,
        [String] $releaseFolder
    )
    $acctName = ""
    $bla = $connectionString.Split(";")
    foreach($item in $bla) {
        $kv = ([String]$item).Split("=")
        if($kv[0] -eq "AccountName") {
            $acctName = $kv[1]
            break
        }
    }

    Write-Output ("https://" + $acctName + ".blob.core.windows.net/" + $releaseFolder + "/")
}

$config = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
$location = $config.location
$adminPass = $config.adminPass
$storageCS = $config.storageConnectionString
$httpPrivateKey = $config.httpsPrivateKey
$httpPublicKey = $config.httpsPublicKey
$jumpboxResourceGroup = $config.jumpboxResourceGroup

if($prebuiltReleaseFolder -ne "")
{
    $releaseFolder = $prebuiltReleaseFolder
} else {
    $releaseFolder = ('dev' + (get-date).ToString('MMddyyhhmmss'))
    .\package.ps1 $releaseFolder $buildDashboard
}

Set-Location ".\$releaseFolder"
Expand-Archive "marketplacePackage.zip"
Set-Location ".\marketplacePackage"
az storage container create -n $releaseFolder --connection-string $storageCS
az storage blob upload -c ($releaseFolder) -f "mp_mm_setup.ps1" -n "mp_mm_setup.ps1" --connection-string $storageCS
az storage blob upload -c ($releaseFolder) -f "mp_ss_setup.ps1" -n "mp_ss_setup.ps1" --connection-string $storageCS
az storage blob upload -c ($releaseFolder) -f "msImprovedWebservers.zip" -n "msImprovedWebservers.zip" --connection-string $storageCS
az storage blob upload -c ($releaseFolder) -f "msPrereqs.zip" -n "msPrereqs.zip" --connection-string $storageCS
az storage blob upload -c ($releaseFolder) -f "msDashboard.zip" -n "msDashboard.zip" --connection-string $storageCS

$containerLocation = Get-StorageAccountName $storageCS $releaseFolder

$end = (Get-Date).ToUniversalTime()
$end = $end.addYears(1)
$endsas = ($end.ToString("yyyy-MM-ddTHH:mm:ssZ"))
$sas = az storage container generate-sas -n $releaseFolder --https-only --permissions r --expiry $endsas -o tsv --connection-string $storageCS
$sas = ("?" + $sas)
Set-Location "..\..\"
Set-Location "..\arm"
az group create -n $resourceGroup -l $location
az deployment group create -f mainTemplate.bicep --parameters "@createUiDefinition.parameters.json" -g $resourceGroup --parameters location=$location --parameters basics_adminPass=$adminPass --parameter _artifactsLocation=$containerLocation --parameter _artifactsLocationSasToken="""$sas""" --parameter security_httpsPrivateKey=$httpPrivateKey security_httpsPublicKey=$httpPublicKey
Set-Location "..\package"

if($jumpboxResourceGroup -ne "")
{
    Write-Host "Now setting up the peering from the jumpbox to the regions"
    .\setupPeeringToJumpbox.ps1 $resourceGroup $jumpboxResourceGroup
}

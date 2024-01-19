# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
Param (
  [Parameter(Mandatory = $True, HelpMessage = "subscription id from terraform")]
  [String]$subscriptionId = "",
  [Parameter(Mandatory = $True, HelpMessage = "global rg name")]
  [String]$globalRgName = "",
  [Parameter(Mandatory = $True, HelpMessage = "global rg location")]
  [String]$globalRgLocation = "",
  [Parameter(Mandatory = $True, HelpMessage = "resource group name")]
  [String]$resourceGroupName = "",
  [Parameter(Mandatory = $True, HelpMessage = "vmss name")]
  [String]$vmssName = "",
  [Parameter(Mandatory = $True, HelpMessage = "application insights key")]
  [String]$appInsightsInstrumentationKey = "",
  [Parameter(Mandatory = $False, HelpMessage = "downloadUri of 3D app")]
  [String]$unrealApplicationDownloadUri = "",
  [Parameter(Mandatory = $False, HelpMessage = "scaling setting - enable auto scaling flag")]
  [String]$enableAutoScale = "true",
  [Parameter(Mandatory = $False, HelpMessage = "scaling setting - instance count buffer")]
  [int]$instanceCountBuffer = 1,
  [Parameter(Mandatory = $False, HelpMessage = "scaling setting - percentage buffer")]
  [int]$percentBuffer = 25,
  [Parameter(Mandatory = $False, HelpMessage = "scaling setting - nr of minutes to wait before next scaledown")]
  [int]$minMinutesBetweenScaledowns = 60,
  [Parameter(Mandatory = $False, HelpMessage = "scaling setting - amount of nodes to scale down by")]
  [int]$scaleDownByAmount = 1,
  [Parameter(Mandatory = $False, HelpMessage = "scaling setting - min nr of instances")]
  [int]$minInstanceCount = 0,
  [Parameter(Mandatory = $False, HelpMessage = "scaling setting - max nr of instances")]
  [int]$maxInstanceCount = 250,
  [Parameter(Mandatory = $False, HelpMessage = "network setting - matchmaker public port")]
  [int]$matchmakerPublicPort = 80,
  [Parameter(Mandatory = $False, HelpMessage = "network setting - matchmaker internal port")]
  [int]$matchmakerInternalPort = 9999,
  [Parameter(Mandatory = $False, HelpMessage = "enable the Admin site on this MM instance")]
  [String]$isMainMatchmaker = "false",
  [Parameter(Mandatory = $false, HelpMessage = "Desired instances of 3D apps running per VM, default 1")]
  [int] $instancesPerNode = 1,
  [Parameter(Mandatory = $false, HelpMessage = "The resolution width of the 3D app, default 1920")]
  [int] $resolutionWidth = 1920,
  [Parameter(Mandatory = $false, HelpMessage = "The resolution height of the 3D app, default 1080")]
  [int] $resolutionHeight = 1080,
  [Parameter(Mandatory = $false, HelpMessage = "The name of the 3D app, default is empty")]
  [string] $pixelstreamingApplicationName = "",
  [Parameter(Mandatory = $false, HelpMessage = "The frames per second of the 3D app, default -1 which reverts to default behavior of UE")]
  [int] $fps = -1,
  [Parameter(Mandatory = $True, HelpMessage = "matchmaker internal API IP Address")]
  [String]$matchmakerInternalApiAddress = "",
  [Parameter(Mandatory = $True, HelpMessage = "matchmaker internal API Port")]
  [int]$matchmakerInternalApiPort = 81,
  [Parameter(Mandatory = $False, HelpMessage = "connectionstring to the admin storage account")]
  [String]$storageConnectionString = "false",
  [Parameter(Mandatory = $False, HelpMessage = "were changes made to MM/SS by the user")]
  [String]$userModifications = "false",
  [Parameter(Mandatory = $False, HelpMessage = "enable auth API on this MM instance")]
  [String]$enableAuthentication = "false",
  [Parameter(Mandatory = $False, HelpMessage = "Enable HTTPS")]
  [String]$enableHttps = "false",
  [Parameter(Mandatory = $False, HelpMessage = "Custom Domain Name")]
  [String]$customDomainName = "",
  [Parameter(Mandatory = $False, HelpMessage = "Azure DNS ResourceGroup")]
  [String]$dnsConfigRg = "",
  [Parameter(Mandatory = $False, HelpMessage = "Subdomain for Traffic Manager URL")]
  [String]$tmSubdomainName = "",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Address")]
  [String]$turnServerAddress = "",
  [Parameter(Mandatory = $False, HelpMessage = "STUN Server Address")]
  [String]$stunServerAddress = "",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Username")]
  [String]$turnUsername = "",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Password")]
  [String]$turnPassword = "",
  [Parameter(Mandatory = $False, HelpMessage = "Storage Account Name")]
  [String]$storageAccountName = "",
  [Parameter(Mandatory = $False, HelpMessage = "Storage Account Key")]
  [String]$storageAccountKey = "",
  [Parameter(Mandatory = $False, HelpMessage = "Custom Image Name")]
  [String]$customImageName = ""
)

$StartTime = Get-Date

#####################################################################################################
#base variables
#####################################################################################################
$version = 1
$logsfolder = "c:\gaming\logs"
$logoutput = $logsfolder + '\ue4-setupMM-output-' + (get-date).ToString('MMddyyhhmmss') + '.txt'
$folder = "c:\Unreal_$version\"
$baseAdminTableName = "admin"
$baseAdminBlobContainerName = "zips" 
$baseAdminUploadsBlobContainerName = "uploads" # Used for update workflow
$baseUserTableName = "users"
$taskName = "StartMMS_$version"
$aiKeyName = "admindashboard"
$enableAutoScale_bool = (&{If($enableAutoScale -eq "True") {$true} Else {$false}})
$isMainMatchmaker_bool = (&{If($isMainMatchmaker -eq "True") {$true} Else {$false}})
$enableAuthentication_bool = (&{If($enableAuthentication -eq "True") {$true} Else {$false}})
$enableHttps_bool = (&{If($enableHttps -eq "True") {$true} Else {$false}})
$userModifications_bool = (&{If($userModifications -eq "True") {$true} Else {$false}})
$downloadFolder = "c:\tmp"
$downloadUA4File = "unreal_$version.zip"
$downloadMsImprovedWebserversFile = "msImprovedWebservers.zip"
$downloadMsPrereqsFile = "msPrereqs.zip"
$downloadUA4Destination = ($downloadFolder + "\" + $downloadUA4File)
$downloadMsImprovedWebserversDestination = ($downloadFolder + "\" + $downloadMsImprovedWebserversFile)
$downloadMsPrereqsDestination = ($downloadFolder + "\" + $downloadMsPrereqsFile)
$deploymentLocation = $resourceGroupName.Split('-')[1]

$folderNoTrail = $folder
if ($folderNoTrail.EndsWith("\")) {
  $l = $folderNoTrail.Length - 1
  $folderNoTrail = $folderNoTrail.Substring(0, $l)
}

$relativeMMPath = "WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers\Matchmaker"
$mmServiceFolder = "$folderNoTrail\" + $relativeMMPath
$mmCertFolder = $mmServiceFolder + "\Certificates"
$executionfilepath = "$folderNoTrail\scripts\startMMS.ps1"

### STORE PARAMS FOR LATER USE ###
$paramsFolder = "C:\CSE-params"
New-Item -Path $paramsFolder -ItemType directory -Force
$config = @{}
$config.Add("subscriptionId", $subscriptionId)
$config.Add("globalRgName", $globalRgName)
$config.Add("globalRgLocation", $globalRgLocation)
$config.Add("resourceGroupName", $resourceGroupName)
$config.Add("vmssName", $vmssName)
$config.Add("appInsightsInstrumentationKey", $appInsightsInstrumentationKey)
$config.Add("unrealApplicationDownloadUri", $unrealApplicationDownloadUri.replace('%26', '&'))
$config.Add("enableAutoScale", $enableAutoScale)
$config.Add("instanceCountBuffer", $instanceCountBuffer)
$config.Add("percentBuffer", $percentBuffer)
$config.Add("minMinutesBetweenScaledowns", $minMinutesBetweenScaledowns)
$config.Add("scaleDownByAmount", $scaleDownByAmount)
$config.Add("minInstanceCount", $minInstanceCount)
$config.Add("maxInstanceCount", $maxInstanceCount)
$config.Add("matchmakerPublicPort", $matchmakerPublicPort)
$config.Add("matchmakerInternalApiAddress", $matchmakerInternalApiAddress)
$config.Add("matchmakerInternalApiPort", $matchmakerInternalApiPort)
$config.Add("matchmakerInternalPort", $matchmakerInternalPort)
$config.Add("enableAuthentication", $enableAuthentication)
$config.Add("instancesPerNode", $instancesPerNode)
$config.Add("resolutionWidth", $resolutionWidth)
$config.Add("resolutionHeight", $resolutionHeight)
$config.Add("pixelstreamingApplicationName", $pixelstreamingApplicationName)
$config.Add("fps", $fps)
$config.Add("storageConnectionString", $storageConnectionString)
$config.Add("userModifications", $userModifications)
$config.Add("deploymentLocation", $deploymentLocation)
$config.Add("enableHttps", $enableHttps)
$config.Add("customDomainName", $customDomainName)
$config.Add("dnsConfigRg", $dnsConfigRg)
$config.Add("tmSubdomainName", $tmSubdomainName)

$config | ConvertTo-Json | Set-Content "$paramsFolder\params.json"

$base_name = $config.vmssName.Substring(0, $config.resourceGroupName.IndexOf("-"))
$akv = "akv-$base_name"

[System.Net.ServicePointManager]::Sec
tyProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force

New-Item -Path $logsfolder -ItemType directory -Force
function logmessage() {
  $logmessage = $args[0]    
  $MessageTime = Get-Date -Format "[MM/dd/yyyy HH:mm:ss]"

  $output = "$MessageTime - $logmessage"
  Add-Content -Path $logoutput -Value $output
}

logmessage "Starting BE Setup at:$StartTime"
logmessage "Disabling Windows Firewalls started"
New-NetFirewallRule -DisplayName "Matchmaker-IB-$config.matchmakerPublicPort" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $config.matchmakerPublicPort
New-NetFirewallRule -DisplayName "Matchmaker-IB-$config.matchmakerInternalPort" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $config.matchmakerInternalPort
New-NetFirewallRule -DisplayName "Matchmaker-IB-$config.matchmakerInternalApiPort" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $config.matchmakerInternalApiPort
if ($enableHttps_bool -eq $true) {
  New-NetFirewallRule -DisplayName 'Matchmaker-IB-443' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 443
}
logmessage "Disabling Windows Firewalls complete"

logmessage "Creating: $folder"
New-Item -Path $folder -ItemType directory

logmessage "Downloading assets and unzipping"
if ( (Get-ChildItem $folderNoTrail | Measure-Object).Count -eq 0) {
  try {
    New-Item -Path $downloadFolder -ItemType directory
    $wsFolder = ($folder + "WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers")

    #this makes sure that Invoke-WebRequest just downloads, and doesnt give the UI updates. Makes it 95% faster...
    $ProgressPreference = 'SilentlyContinue'

    #copy the files we got from the ARM deployment
    Copy-Item ".\$downloadMsImprovedWebserversFile" -Destination "$downloadMsImprovedWebserversDestination"
    Copy-Item ".\$downloadMsPrereqsFile" -Destination "$downloadMsPrereqsDestination"

    #fetch and unzip the UE4 App + Webservers if the user made modification. If they did not make modifications we don't need to download the package on the MM as we will override the Webservers folder anywway
    $unrealApplicationDownloadUri = $unrealApplicationDownloadUri.replace('%26', '&')
    if($userModifications_bool -eq $true) {
      logmessage "User modified MM and SS should be available so check if custom image is present before downloading from URI"
      $preExistingAppFolder = "C:\App"
      if($customImageName) {
        #There is no need to check for the zip file. Now, say user has C:\App\youapp.zip
        #For MM and SS in any case the user would have to unzip the file to copy paste custom MM and SS
        # Therefore, check for zip file can be skipped. 
        $appFolderName = (Get-ChildItem $preExistingAppFolder -directory | Select-Object -First 1)
        if ($null -ne $appFolderName) {
          logmessage "App will be copied from: ", $appFolderName.FullName, " to the path : $folder"
          Copy-Item -Path $appFolderName.FullName -Destination $folder -Recurse -Exclude "*.zip"
          if ($appFolderName -ne "WindowsNoEditor") {
            Rename-Item -Path "$folderNoTrail\$appFolderName" -NewName "WindowsNoEditor"
          }
          logmessage "Assuming Webserver path $wsFolder is already present"
          if (Test-Path -Path $wsFolder) {
            logmessage "Webservers folder is present as expected"
          } else {
            logmessage "Webserver folder is not present. User should set User modification bool to false."
            logmessage "This deployment will fail"
          }
        }
      } else {
        logmessage "Since the user has provided custom MM code but custome image is not present so download from $unrealApplicationDownloadUri"
        az storage blob download --blob-url """$unrealApplicationDownloadUri""" -f $downloadUA4Destination
        7z x $downloadUA4Destination ("-o"+$folder) -bd

        $appFolderName = (Get-ChildItem $folder -directory | Select-Object -First 1).Name
        logmessage "App folder name given by the user $appFolderName"
        if (($null -ne $appFolderName) -and ($appFolderName -ne 'WindowsNoEditor')) {
          logmessage "Renamining app folder to WindowsNoEditor"
          Rename-Item -Path "$folderNoTrail\$appFolderName" -NewName "WindowsNoEditor"
        }
      }
    }
    
    7z x $downloadMsPrereqsDestination ("-o"+$folder) -bd

    if($userModifications_bool -eq $false) {
      logmessage "Since user modification is false therefore installing our own Webservers"
      # No user modifications were made to the webservers, so we delete the old ones, and replace them with ours
      Remove-item -Path $wsFolder -Recurse
      New-Item -Path $wsFolder -ItemType directory
      7z x $downloadMsImprovedWebserversDestination ("-o"+$wsFolder) -bd
    }
  }
  catch {
    logmessage "Error message: " + $_
    break
  }
} 
else { 
  logmessage "Unreal Folder was not Empty. ABORTING."
  logmessage "Error message: " + $_
  break
}

logmessage "Az Login"
az login --identity
logmessage "Az Set Subscription"
az account set --subscription $config.subscriptionId

logmessage "isMainMatchmaker_bool: $isMainMatchmaker_bool"

if($isMainMatchmaker_bool)
{
  ### SEED THE ADMIN TABLE STORAGE TABLE ###
  logmessage "Creating Admin Table and seeding it with V1"
  $enableAutoScaleLC = $config.enableAutoScale.ToLower()

  az storage table create --name $baseAdminTableName --connection-string $config.storageConnectionString
  az storage entity insert --connection-string $config.storageConnectionString `
    --table-name $baseAdminTableName `
    --entity PartitionKey=$baseAdminTableName `
    RowKey=999999 `
    version=1 version@odata.type=Edm.Int32 `
    instancesPerNode=$instancesPerNode instancesPerNode@odata.type=Edm.Int32 `
    resolutionWidth=$resolutionWidth resolutionWidth@odata.type=Edm.Int32 `
    resolutionHeight=$resolutionHeight resolutionHeight@odata.type=Edm.Int32 `
    pixelstreamingApplicationName=$pixelstreamingApplicationName `
    fps=$fps fps@odata.type=Edm.Int32 `
    unrealApplicationDownloadUri="""$downloadUA4File""" `
    msImprovedWebserversDownloadUri="""$downloadMsImprovedWebserversFile""" `
    msPrereqsDownloadUri="""$downloadMsPrereqsFile""" `
    enableAutoScale=$enableAutoScaleLC enableAutoScale@odata.type=Edm.Boolean `
    instanceCountBuffer=$instanceCountBuffer instanceCountBuffer@odata.type=Edm.Int32 `
    percentBuffer=$percentBuffer percentBuffer@odata.type=Edm.Int32 `
    minMinutesBetweenScaledowns=$minMinutesBetweenScaledowns minMinutesBetweenScaledowns@odata.type=Edm.Int32 `
    scaleDownByAmount=$scaleDownByAmount scaleDownByAmount@odata.type=Edm.Int32 `
    minInstanceCount=$minInstanceCount minInstanceCount@odata.type=Edm.Int32 `
    maxInstanceCount=$maxInstanceCount maxInstanceCount@odata.type=Edm.Int32 `
    stunServerAddress="""$stunServerAddress""" `
    turnServerAddress="""$turnServerAddress""" `
    turnUsername="""$turnUsername""" `
    turnPassword="""$turnPassword""" `

  ### CREATE the USERS TABLE ###
  if ($enableAuthentication_bool) {
    az storage table create --name $baseUserTableName --connection-string $config.storageConnectionString
  }
  
  ### SETUP AN APP INSIGHTS API KEY ###
  # az monitor app-insights is extension. the following line will install that extension without prompt when we use the extension for the first time
  az config set extension.use_dynamic_install=yes_without_prompt

  $ais = az monitor app-insights component show -g $config.globalRgName | ConvertFrom-Json
  $aiName = $ais[0].applicationId
  $aiAppId = $ais[0].appId

  # make the call to add the api key
  $aiKeyCreateResult = az monitor app-insights api-key create --api-key $aiKeyName --app $aiName -g $config.globalRgName --read-properties ReadTelemetry | ConvertFrom-Json
  $aiApiKey = $aiKeyCreateResult.apiKey
  logmessage "Added AppInsights API Key for key $aiKeyName"

  # store appInsights appId + apiKey in keyvault
  az keyvault secret set --vault-name $akv --name "appInsightsApiKey" --value $aiApiKey
  az keyvault secret set --vault-name $akv --name "appInsightsApplicationId" --value $aiAppId

  ### STORE ZIP FILES IN BLOB STORAGE ACCOUNT ###
  # Don't use decode function here because say SAS say %3D in it, the decode function 
  # will replace if with = character. 
  logmessage "Starting copying"
  az storage container create -n $baseAdminBlobContainerName --connection-string $config.storageConnectionString
  az storage container create -n $baseAdminUploadsBlobContainerName --connection-string $config.storageConnectionString

  if ($customImageName -eq '') {
    logmessage "Since Custom Image is not available. Therefore, we will download the app"
    $unrealApplicationDownloadUri = $unrealApplicationDownloadUri.replace('%26', '&')
    logmessage "App package will be uploaded from : $unrealApplicationDownloadUri"
    $flattenedConnectionString = $config.storageConnectionString | Out-String
    logmessage "flattenedConnectionString: $flattenedConnectionString"
    
    $end = (Get-Date).ToUniversalTime()
    $end = $end.addYears(1)
    $endsas = ($end.ToString("yyyy-MM-ddTHH:mm:ssZ"))
    $sasToken = az storage container generate-sas --account-name $storageAccountName --account-key $storageAccountKey --name $baseAdminBlobContainerName --permissions dlrw --expiry $endsas -o tsv
    $sasTokenUploadFolder = az storage container generate-sas --account-name $storageAccountName --account-key $storageAccountKey --name $baseAdminUploadsBlobContainerName --permissions dlrw --expiry $endsas -o tsv
    $connectionStringWithSAS = $flattenedConnectionString + ';' + $sasToken
    $connectionStringWithSASUploadFolder = $flattenedConnectionString + ';' + $sasTokenUploadFolder
    logmessage "ConnectionStringWithSAS: $connectionStringWithSAS"
    az storage blob copy start -c $baseAdminBlobContainerName -b $downloadUA4File  -u """$unrealApplicationDownloadUri""" --connection-string $connectionStringWithSAS 
    logmessage "Started copying App to the storage account"

    #Upload the same copy in uploads folder as well for update workflow
    az storage blob copy start -c $baseAdminUploadsBlobContainerName -b $downloadUA4File  -u """$unrealApplicationDownloadUri""" --connection-string $connectionStringWithSASUploadFolder 
  } else {
    logmessage "Custom Image name was found: ", $customImageName
    logmessage "Skipping uploading the file to the storage account"
  }
  
  az storage blob upload -c $baseAdminBlobContainerName -n $downloadMsImprovedWebserversFile -f $downloadMsImprovedWebserversDestination --connection-string $config.storageConnectionString
  az storage blob upload -c $baseAdminBlobContainerName -n $downloadMsPrereqsFile -f $downloadMsPrereqsDestination --connection-string $config.storageConnectionString

  # do webapp deployment, as ARM template ZipDeploy fails 3/4 times...
  $dashboardFile = Get-Item "msDashboard.zip";
  az webapp deployment source config-zip -n ($base_name+"-dashboard") -g $config.globalRgName --src $dashboardFile

  if($config.customDomainName -ne "")
  {
    # if custom domain is set, we create a CNAME record for the traffic manager
    $tmFqdn = ($base_name+"-trafficmgr-mm.trafficmanager.net")
    az network dns record-set cname create -n $config.tmSubdomainName -g $config.dnsConfigRg -z $config.customDomainName --metadata "randomString=$base_name"
    az network dns record-set cname set-record -c $tmFqdn -n $config.tmSubdomainName -g $config.dnsConfigRg -z $config.customDomainName
  }
}

#logic for adding c
if($config.customDomainName -ne "")
{
  logmessage "Adding MM to DNS as CustomDomain is configured"
  $publicIp = az vm show -d -g $config.resourceGroupName -n ($base_name+"-mm-vm-"+$config.deploymentLocation) --query publicIps -o tsv
  $domainNameLabel = ($base_name+"-mm-"+$config.deploymentLocation)

  logmessage "Adding DNS label $domainNameLabel to IP address $publicIp"
  az network dns record-set a create -n $domainNameLabel -g $config.dnsConfigRg -z $config.customDomainName --metadata "randomString=$base_name"
  az network dns record-set a add-record -a $publicIp -n $domainNameLabel -g $config.dnsConfigRg -z $config.customDomainName
}

#put a check here if the clone actually occurred, if not break
try {
  Set-Location -Path $mmServiceFolder 
}
catch {
  logmessage $_.Exception.Message
  break
}
finally {
  $error.clear()
}
logmessage "Current folder: $mmServiceFolder"

$mmConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
logmessage "Config json before update : $mmConfigJson"

$mmConfigJson.httpPort = $config.matchmakerPublicPort
$mmConfigJson.resourceGroup = $config.resourceGroupName
$mmConfigJson.subscriptionId = $config.subscriptionId
$mmConfigJson.virtualMachineScaleSet = $config.vmssName
$mmConfigJson.appInsightsInstrumentationKey = $config.appInsightsInstrumentationKey
$mmConfigJson.instancesPerNode = $config.instancesPerNode
$mmConfigJson.enableAutoScale = $enableAutoScale_bool
$mmConfigJson.instanceCountBuffer = $config.instanceCountBuffer
$mmConfigJson.percentBuffer = $config.percentBuffer
$mmConfigJson.minMinutesBetweenScaledowns = $config.minMinutesBetweenScaledowns
$mmConfigJson.scaleDownByAmount = $config.scaleDownByAmount
$mmConfigJson.minInstanceCount = $config.minInstanceCount
$mmConfigJson.maxInstanceCount = $config.maxInstanceCount
$mmConfigJson.matchmakerInternalApiAddress = $config.matchmakerInternalApiAddress
$mmConfigJson.matchmakerInternalApiPort = $config.matchmakerInternalApiPort
$mmConfigJson.matchmakerPort = $config.matchmakerInternalPort
$mmConfigJson.enableAuthentication = $enableAuthentication_bool
$mmConfigJson.storageConnectionString = $config.storageConnectionString
$mmConfigJson.region = $config.deploymentLocation
$mmConfigJson.enableHttps = $enableHttps_bool
$mmConfigJson.customDomainName = $config.customDomainName
$mmConfigJson.dnsConfigRg = $config.dnsConfigRg

$mmConfigJson | ConvertTo-Json | set-content "config.json"

# Reading again to confirm the update
$mmConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
logmessage "Writing parameters from extension complete." 
logmessage "Updated config : $mmConfigJson"

#create the certificates folder
$mmCertFolder = $mmServiceFolder + "\certificates"

if (-not (Test-Path -LiteralPath $mmCertFolder)) {
  $fso = new-object -ComObject scripting.filesystemobject
  $fso.CreateFolder($mmCertFolder)
}
else {
  logmessage "Path already exists: $mmCertFolder"
}

#set the path to the certificates folder
Set-Location -Path $mmCertFolder 

logmessage "Starting Certificate Process"
logmessage "AKV: $akv"

#check to see if the key exists?
$certs = (az keyvault secret list --vault-name $akv --query "[?starts_with(name, 'https-')]") | ConvertFrom-Json

#download the cert to the folder
if ($certs.Length -eq 2) {
  try {
    # download the private key
    $cert = az keyvault secret show --vault-name $akv -n "https-privatekey" --query "value" | ConvertFrom-Json
    $file = "client-key.pem"
    $decodedText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cert))
    New-Item -Path $file -Type File -Value $decodedText -Force
    
    # download the public key
    $cert = az keyvault secret show --vault-name $akv -n "https-publickey" --query "value" | ConvertFrom-Json
    $file = "client-cert.pem"
    $decodedText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cert))
    New-Item -Path $file -Type File -Value $decodedText -Force

    logmessage "Certificates Download Succeeded"
  }
  catch {
    logmessage "Certificates Download Failed"
  }
}
else {
  logmessage "Certificate does not exist"
}

logmessage "Creating a job schedule "

$trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:10
try {
  $User = "NT AUTHORITY\SYSTEM"
  $PS = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ("-executionpolicy bypass -noprofile -file $executionfilepath " + $version)
  Register-ScheduledTask -Trigger $trigger -User $User -TaskName $taskName -Action $PS -RunLevel Highest -Force 
}
catch {
  logmessage "Exception: " + $_.Exception
}
finally {
  $error.clear()    
}

logmessage "Creating a job schedule complete"
logmessage "Starting the MMS Process "

#invoke the script to start it this time
#Invoke-Expression -Command $executionfilepath
Start-ScheduledTask -TaskName $taskName -AsJob

$EndTime = Get-Date
logmessage "Completed at:$EndTime"

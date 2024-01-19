#Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
Param (
  [Parameter(Mandatory = $True, HelpMessage = "subscription id from terraform")]
  [String]$subscriptionId = "",
  [Parameter(Mandatory = $True, HelpMessage = "resource group name")]
  [String]$resourceGroupName = "",
  [Parameter(Mandatory = $True, HelpMessage = "vmss name")]
  [String]$vmssName = "",
  [Parameter(Mandatory = $True, HelpMessage = "application insights key")]
  [String]$appInsightsInstrumentationKey = "",
  [Parameter(Mandatory = $True, HelpMessage = "matchmaker load balancer fqdn")]
  [String]$mm_lb_fqdn = "",
  [Parameter(Mandatory = $false, HelpMessage = "Desired instances of 3D apps running per VM, default 1")]
  [int] $instancesPerNode = 1,
  [Parameter(Mandatory = $false, HelpMessage = "The streaming port start for multiple instances, default 8888")]
  [int] $streamingPort = 8888,
  [Parameter(Mandatory = $false, HelpMessage = "The resolution width of the 3D app, default 1920")]
  [int] $resolutionWidth = 1920,
  [Parameter(Mandatory = $false, HelpMessage = "The resolution height of the 3D app, default 1080")]
  [int] $resolutionHeight = 1080,
  [Parameter(Mandatory = $false, HelpMessage = "The name of the 3D app")]
  [string] $pixelstreamingApplicationName = "",
  [Parameter(Mandatory = $false, HelpMessage = "The frames per second of the 3D app, default -1 which reverts to default behavior of UE")]
  [int] $fps = -1,
  [Parameter(Mandatory = $False, HelpMessage = "downloadUri of 3D app")]
  [String]$unrealApplicationDownloadUri = "",
  [Parameter(Mandatory = $False, HelpMessage = "network setting - signalling server public port")]
  [int]$signallingserverPublicPortStart = 80,
  [Parameter(Mandatory = $False, HelpMessage = "network setting - matchmaker internal port")]
  [int]$matchmakerInternalPort = 9999,
  [Parameter(Mandatory = $True, HelpMessage = "matchmaker internal API IP Address")]
  [String]$matchmakerInternalApiAddress = "",
  [Parameter(Mandatory = $True, HelpMessage = "matchmaker internal API Port")]
  [int]$matchmakerInternalApiPort = 81,
  [Parameter(Mandatory = $False, HelpMessage = "were changes made to MM/SS by the user")]
  [String]$userModifications = "false",
  [Parameter(Mandatory = $False, HelpMessage = "Enable HTTPS")]
  [String]$enableHttps = "false",
  [Parameter(Mandatory = $False, HelpMessage = "Custom Domain Name")]
  [String]$customDomainName = "",
  [Parameter(Mandatory = $False, HelpMessage = "Azure DNS ResourceGroup")]
  [String]$dnsConfigRg = "",
  [Parameter(Mandatory = $False, HelpMessage = "enable Authentication")]
  [String]$enableAuthentication = "false",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Address")]
  [String]$turnServerAddress = "",
  [Parameter(Mandatory = $False, HelpMessage = "STUN Server Address")]
  [String]$stunServerAddress = "",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Username")]
  [String]$turnUsername = "",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Password")]
  [String]$turnPassword = "",
  [Parameter(Mandatory = $False, HelpMessage = "Custom Image Name")]
  [String]$customImageName = "",
  [Parameter(Mandatory=$false, HelpMessage = "Option to enable Pixel Streaming commands ")]
  [string] $allowPixelStreamingCommands = "false"
)

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force

$StartTime = Get-Date
$version = 1
$logsfolder = "c:\gaming\logs"
New-Item -Path $logsfolder -ItemType directory -Force
$logoutput = $logsfolder + '\ue4-setupVMSS-output-' + (get-date).ToString('MMddyyhhmmss') + '.txt'

function logmessage() {
  $logmessage = $args[0]
  $MessageTime = Get-Date -Format "[MM/dd/yyyy HH:mm:ss]"

  $output = "$MessageTime - $logmessage"
  Add-Content -Path $logoutput -Value $output
}

logmessage "Starting BE Setup at:$StartTime"
### SEE IF THE MATCHMAKER ADMIN API IS UP AND RUNNING... IF IT IS WE FETCH THE LATEST VARIABLES ###
$settingsApi = ("http://" + $matchmakerInternalApiAddress + ":" + $matchmakerInternalApiPort + "/api/settings/latest")
logmessage $settingsApi
$appAvailable = $false
$retries = 0
do {
  try {
    $response = Invoke-WebRequest -Uri $settingsApi -UseBasicParsing
    $settings = $response.Content | ConvertFrom-Json
  
    logmessage "Getting a 200 response from Admin API"
  
    $version = $settings.version
    $instancesPerNode = $settings.instancesPerNode
    $resolutionWidth = $settings.resolutionWidth
    $resolutionHeight = $settings.resolutionHeight
    $pixelstreamingApplicationName = $settings.pixelstreamingApplicationName
    $fps = $settings.fps
    $unrealApplicationDownloadUri = $settings.unrealApplicationDownloadUri
    
    $appAvailable = $true
    logmessage "Received unrealApplicationDownloadUri from the table: $unrealApplicationDownloadUri"
  } catch {
    logmessage "Admin API is not running... assuming initial deployment, not a scaleout $_"
    $retries++
    Start-Sleep -Seconds 30
  }
} until ($appAvailable -or ($retries -ge 15))

$folder = "c:\Unreal_$version\"
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

### STORE PARAMS FOR LATER USE ###
$paramsFolder = "C:\CSE-params"
New-Item -Path $paramsFolder -ItemType directory -Force
$config = @{}
$config.Add("subscriptionId", $subscriptionId)
$config.Add("resourceGroupName", $resourceGroupName)
$config.Add("vmssName", $vmssName)
$config.Add("appInsightsInstrumentationKey", $appInsightsInstrumentationKey)
$config.Add("mm_lb_fqdn", $mm_lb_fqdn)
$config.Add("instancesPerNode", $instancesPerNode)
$config.Add("streamingPort", $streamingPort)
$config.Add("resolutionWidth", $resolutionWidth)
$config.Add("resolutionHeight", $resolutionHeight)
$config.Add("pixelstreamingApplicationName", $pixelstreamingApplicationName)
$config.Add("fps", $fps)
$config.Add("unrealApplicationDownloadUri", $unrealApplicationDownloadUri.replace('%26', '&'))
$config.Add("signallingserverPublicPortStart", $signallingserverPublicPortStart)
$config.Add("matchmakerInternalPort", $matchmakerInternalPort)
$config.Add("matchmakerInternalApiAddress", $matchmakerInternalApiAddress)
$config.Add("matchmakerInternalApiPort", $matchmakerInternalApiPort)
$config.Add("userModifications", $userModifications)
$config.Add("deploymentLocation", $deploymentLocation)
$config.Add("enableHttps", $enableHttps)
$config.Add("enableAuthentication", $enableAuthentication)
$config.Add("customDomainName", $customDomainName)
$config.Add("dnsConfigRg", $dnsConfigRg)
$config.Add("turnServerAddress", $turnServerAddress)
$config.Add("stunServerAddress", $stunServerAddress)
$config.Add("turnUsername", $turnUsername)
$config.Add("turnPassword", $turnPassword)
$config.Add("allowPixelStreamingCommands", $allowPixelStreamingCommands)

$userModifications_bool = (&{If($config.userModifications -eq "True") {$true} Else {$false}})
$enableHttps_bool = (&{If($config.enableHttps -eq "True") {$true} Else {$false}})
$enableAuthentication_bool = (&{If($config.enableAuthentication -eq "True") {$true} Else {$false}})
$enablePixelStreamingCommands_bool = (&{If($config.allowPixelStreamingCommands -eq "True") {$true} Else {$false}})

$vmServiceFolder = "$folderNoTrail\WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers\SignallingWebServer"
$vmWebServicesFolder = "$folderNoTrail\WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers\"
$executionfilepath = "$folderNoTrail\scripts\startVMSS.ps1"

$base_name = $vmssName.Substring(0, $config.resourceGroupName.IndexOf("-"))
$akv = "akv-$base_name"

logmessage "Disabling Windows Firewalls started"
For ($i=1; $i -le $config.instancesPerNode; $i++) {
    $newPublicPort = $config.signallingserverPublicPortStart + $i - 1;
    New-NetFirewallRule -DisplayName "SignallingServer-IB-$newPublicPort" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $newPublicPort
}

New-NetFirewallRule -DisplayName ("SignallingServer-OB-"+$config.matchmakerInternalPort) -Direction Outbound -Action Allow -Protocol TCP -LocalPort $config.matchmakerInternalPort
New-NetFirewallRule -DisplayName ("SignallingServer-OB-"+$config.matchmakerInternalApiPort) -Direction Outbound -Action Allow -Protocol TCP -LocalPort $config.matchmakerInternalApiPort
logmessage "Disabling Windows Firewalls complete"

logmessage "Creating: $folder"
New-Item -Path $folder -ItemType directory

logmessage "Downloading assets and unzipping"
$preExistingAppFolder = "C:\App"

if ( (Get-ChildItem $folderNoTrail | Measure-Object).Count -eq 0) {
  try {
    New-Item -Path "$downloadFolder" -ItemType directory
    $wsFolder = ($folder + "WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers")

    $ProgressPreference = 'SilentlyContinue'
    $retries = 0
    $downloadSuccess = $false
    $extractedApp = $false
    do
    {
      try
      {
        if ($customImageName -and (Test-Path -Path $preExistingAppFolder)) {
          logmessage "Checking if the deployment was done via custom Image"
          #1. Check if the app is extracted already. Assuming we have C:\App\AppName(generally WindowsNoEditor)\Actual Extracted App
          $appFolderName = (Get-ChildItem $preExistingAppFolder -directory | Select-Object -First 1)
          if ($null -ne $appFolderName) {
            logmessage "App is already present in extracted format"
            Copy-Item -Path $appFolderName.FullName -Destination $folder -Recurse -Exclude "*.zip"
            logmessage "Setting extracted app to true to skip the download and extraction of the app"
            $extractedApp = $true
            break
          }

          #2. Check if the zip is present
          $command = (Get-ChildItem -Recurse -Path $preExistingAppFolder -Filter "*.zip"  | Select-Object -First 1)
          if  ($null -ne $command) {
            logmessage "App name provided in the image : ", $command.FullName
            Move-Item -Path $command.FullName -Destination $downloadUA4Destination
            logmessage "File has been moved to the path: $downloadUA4Destination"
            $downloadSuccess = $true
            logmessage "Since the zipped App was found from the base image so skipping download"
            break
          } else {
            logmessage "Zipped App was not found in : $preExistingAppFolder"
          }
        }
        
        logmessage "Trying to download: ", $config.unrealApplicationDownloadUri
        Start-BitsTransfer -Source $config.unrealApplicationDownloadUri -Destination $downloadUA4Destination 
        
        logmessage "File Size: ", (Get-Item -Path $downloadUA4Destination).Length
        if ( (Get-Item -Path $downloadUA4Destination).Length -gt 0 ) {
          logmessage "Reset download success to True to exit the loop"
          $downloadSuccess = $true
        } else {
          logmessage "Set download success to False to keep retrying"
          Start-Sleep -Seconds 60
          $downloadSuccess = $false
        }
      }
      catch
      {
          logmessage ("Retrying download of : $config.unrealApplicationDownloadUri")
          logmessage ("Detailed Error: $_")
          $retries++
          Start-Sleep -Seconds 5
      }
    } until ($downloadSuccess -or ($retries -ge 10))
    Copy-Item ".\$downloadMsImprovedWebserversFile" -Destination "$downloadMsImprovedWebserversDestination"
    Copy-Item ".\$downloadMsPrereqsFile" -Destination "$downloadMsPrereqsDestination"

    if ($extractedApp -ne $true) {
      logmessage "Extracting App"
      7z x $downloadUA4Destination ("-o"+$folder) -bd
    } else {
      logmessage "Skipping App extraction as it is already present"
    }
    
    $appFolderName = (Get-ChildItem $folder -directory | Select-Object -First 1).Name
    
    # Run the following code if the AppName is not known by now
    if (!$config.pixelstreamingApplicationName){
      $command = (Get-ChildItem -Recurse -Depth 3 -Path $folderNoTrail\$appFolderName -Filter "*.exe"  -Exclude "UE*PrereqSetup*.exe","CrashReporter*.exe","EpicWebHelper.exe" | Select-Object -First 1)
      $exeAppName = $command.Basename
      logmessage "The first exe name found in the directory structure: ", $exeAppName
      $config["pixelstreamingApplicationName"] =  $exeAppName

      if ($exeAppName) {
        $pathToApplication = "$folderNoTrail\$appFolderName\$exeAppName" + ".exe"
        #If the file does not exist, create it.
        if (-not(Test-Path -Path $pathToApplication -PathType Leaf)) {
          $command | Copy-Item -Destination $folderNoTrail\$appFolderName
          logmessage "The file [$pathToApplication] has been created."
        }
        # If the file already exists, show the message and do nothing.
        else {
          logmessage "No need to create the file [$pathToApplication] as it exists already."
        }
      } else {
        logmessage "Something went wrong to find the app name"
      }
    }
    # Rename the application folder name to WindowsNoEditor
    if ($appFolderName -ne "WindowsNoEditor") {
      Rename-Item -Path "$folderNoTrail\$appFolderName" -NewName "WindowsNoEditor"
    }
    7z x $downloadMsPrereqsDestination ("-o"+$folder) -bd

    if($userModifications_bool -eq $false) {
      # No user modifications were made to the webservers, so we delete the old ones, and replace them with ours
      Remove-item -Path $wsFolder -Recurse
      New-Item -Path $wsFolder -ItemType directory
      7z x $downloadMsImprovedWebserversDestination ("-o"+$wsFolder) -bd
    }
  }
  catch {
    logmessage "Unreal DL URI: " $_
  }
  finally {
    $error.clear()
  }
}
else {
  logmessage "Unreal Folder was not Empty. ABORTING."
}

$config | ConvertTo-Json | Set-Content "$paramsFolder\params.json"

# logmessage "Start DirectX Installation"
# choco upgrade directx -s ($folder + "choco-packages\directx") -y --no-progress
# logmessage "Completed DirectX Installation"

#Add FPS to Engine.ini if FPS is set to > -1
if ($config.fps -gt -1) {
  logmessage "Start - Adding FPS config to Engine.ini"

  $engineIniFilepath = "$folderNoTrail\WindowsNoEditor\" + $config.pixelstreamingApplicationName + "\Saved\Config\WindowsNoEditor"
  try {
    if (-not (Test-Path -LiteralPath $engineIniFilepath)) {
      logmessage "Cannot find Engine.ini folder - creating it and adding Engine.ini"
      New-Item -Path $engineIniFilepath -ItemType directory
      New-Item -Path ($engineIniFilepath+"\Engine.ini") -ItemType File
    }

    logmessage "Adding FPS config to Engine.ini"

    Add-Content -Path ($engineIniFilepath+"\Engine.ini") -Value ""
    Add-Content -Path ($engineIniFilepath+"\Engine.ini") -Value "[/Script/Engine.Engine]"
    Add-Content -Path ($engineIniFilepath+"\Engine.ini") -Value "bUseFixedFrameRate=True"
    Add-Content -Path ($engineIniFilepath+"\Engine.ini") -Value ("FixedFrameRate=" + $config.fps + ".000000")

    logmessage "Finish - Adding FPS config complete"
  }
  catch {
    logmessage $_.Exception.Message
  }
  finally {
    $error.clear()
  }
}

logmessage "Starting Loop"
#############################################
#Loops through all the instances of the SS we want, and duplciate the directory and setup the config/startup process
for ($instanceNum = 1; $instanceNum -le $config.instancesPerNode; $instanceNum++) {
  try {
    $SSFolder = $vmServiceFolder
    $taskName = "StartVMSS_" + $version + "_" +$instanceNum

    #if we are at more than one instance in the loop we need to duplicate the SS dir
    if ($instanceNum -gt 1) {
      $SSFolder = $vmWebServicesFolder + "SignallingWebServer" + $instanceNum

      #duplicate vmServiceFolder directory
      $newSSFolder = $vmWebServicesFolder + "SignallingWebServer" + $instanceNum
      $sourceFolder = $vmServiceFolder + "*"
      Copy-Item -Path $sourceFolder -Destination $newSSFolder -Recurse
    }

    try {
      Set-Location -Path $SSFolder
    }
    catch {
      logmessage $_.Exception.Message
      break
    }
    finally {
      $error.clear()
    }

    logmessage "Writing paramters from extension: $SSFolder"

    $vmssConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
    logmessage "current config read from config.json : $vmssConfigJson"

    $vmssConfigJson.resourceGroup = $config.resourceGroupName
    $vmssConfigJson.subscriptionId = $config.subscriptionId
    $vmssConfigJson.virtualMachineScaleSet = $config.vmssName
    $vmssConfigJson.appInsightsInstrumentationKey = $config.appInsightsInstrumentationKey
    $vmssConfigJson.matchmakerInternalApiAddress = $config.matchmakerInternalApiAddress
    $vmssConfigJson.matchmakerInternalApiPort = $config.matchmakerInternalApiPort
    $vmssConfigJson.matchmakerAddress = $config.mm_lb_fqdn
    $vmssConfigJson.matchmakerPort = $config.matchmakerInternalPort
    $vmssConfigJson.publicIp = $thispublicip
    $vmssConfigJson.signallingServerPort = ($config.signallingserverPublicPortStart + ($instanceNum - 1))
    $vmssConfigJson.streamerPort = ($config.streamingPort + ($instanceNum - 1))
    $vmssConfigJson.unrealAppName = $config.pixelstreamingApplicationName
    $vmssConfigJson.instanceNr = $instanceNum
    $vmssConfigJson.region = $deploymentLocation
    $vmssConfigJson.enableHttps = $enableHttps_bool
    $vmssConfigJson.enableAuthentication = $enableAuthentication_bool
    $vmssConfigJson.customDomainName = $config.customDomainName
    $vmssConfigJson.dnsConfigRg = $config.dnsConfigRg
    $vmssConfigJson.turnServerAddress = $config.turnServerAddress
    $vmssConfigJson.stunServerAddress = $config.stunServerAddress
    $vmssConfigJson.turnUsername = $config.turnUsername
    $vmssConfigJson.turnPassword = $config.turnPassword
    $vmssConfigJson.allowPixelStreamingCommands = $config.allowPixelStreamingCommands
    $vmssConfigJson | ConvertTo-Json | set-content "config.json"
    $vmssConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json

    logmessage "Writing parameters from extension complete. Updated config : $vmssConfigJson"
  }
  catch {
    logmessage "Exception: ", $_
  }
  finally {
    $error.clear()
  }

  logmessage "Creating a job schedule "

  $trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:10
  try {
    $User = "NT AUTHORITY\SYSTEM"
    $PS = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ("-executionpolicy bypass -noprofile -file $executionfilepath $instanceNum " + $config.streamingPort + " " + $config.resolutionWidth + " " + $config.resolutionHeight + " """ +  $config.pixelstreamingApplicationName + """ " + $version + " " + $enablePixelStreamingCommands_bool)
    Register-ScheduledTask -Trigger $trigger -User $User -TaskName $taskName -Action $PS -RunLevel Highest -AsJob -Force
  }
  catch {
    logmessage "Exception: " + $_.Exception
  }
  finally {
    $error.clear()
  }

  logmessage "Creating a job schedule complete"

  logmessage "Az Login"
  az login --identity
  logmessage "Az Set Subscription"
  az account set --subscription $config.subscriptionId

  ### adding process to download certs
  logmessage "Starting download of certs"

  #create the certificates folder
  $vmCertFolder = $SSFolder + "\certificates"

  if (-not (Test-Path -LiteralPath $vmCertFolder)) {
    $fso = new-object -ComObject scripting.filesystemobject
    $fso.CreateFolder($vmCertFolder)
  }
  else {
    logmessage "Path already exists: $vmCertFolder"
  }

  #set the path to the certificates folder
  Set-Location -Path $vmCertFolder

  if ($enableHttps_bool) 
  {
    $certAvailable = $false 
    logmessage "Enable HTTPS is set to true so downloading HTTPS certificates"
    do {
      try {
        logmessage "Quering Key-Vault: $akv"
        logmessage "Starting private key certificate download"
        $cert = az keyvault secret show --vault-name $akv -n "https-privatekey" --query "value" | ConvertFrom-Json
        $file = "client-key.pem"
        $decodedText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cert))
        New-Item -Path $file -Type File -Value $decodedText -Force

        # download the public key
        logmessage "Starting public key certificate download"
        $cert = az keyvault secret show --vault-name $akv -n "https-publickey" --query "value" | ConvertFrom-Json
        $file = "client-cert.pem"
        $decodedText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cert))
        New-Item -Path $file -Type File -Value $decodedText -Force
        
        logmessage "Certificate download was successful so setting certAvailable to True"
        $certAvailable = $true
      } catch {
        logmessage "Something went wrong while fetching certificates ", $_
        $retries++
        Start-Sleep -Seconds 10*$retries
      }
    } until ($certAvailable -or ($retries -ge 10))
  }

  if (($certAvailable -eq $false) -or ($retries -ge 10)) 
  {
    logmessage "giving up on certificate download as we have already exceeded 10 retries"  
  }

  logmessage "Starting the VMSS Process "

  #execute the scheduled task to start the processes this time
  Start-ScheduledTask -TaskName "$taskName" -AsJob
}
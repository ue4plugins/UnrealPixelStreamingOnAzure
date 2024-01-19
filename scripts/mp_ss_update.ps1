#Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
Param (
  [Parameter(Mandatory = $True, HelpMessage = "subscription id from terraform")]
  [int]$version = "",
  [Parameter(Mandatory = $false, HelpMessage = "Desired instances of 3D apps running per VM, default 1")]
  [int] $instancesPerNode = 1,
  [Parameter(Mandatory = $false, HelpMessage = "The resolution width of the 3D app, default 1920")]
  [int] $resolutionWidth = 1920,
  [Parameter(Mandatory = $false, HelpMessage = "The resolution height of the 3D app, default 1080")]
  [int] $resolutionHeight = 1080,
  [Parameter(Mandatory = $false, HelpMessage = "The name of the 3D app, default PixelStreamingDemo")]
  [string] $pixelstreamingApplicationName = "PixelStreamingDemo",
  [Parameter(Mandatory = $false, HelpMessage = "The frames per second of the 3D app, default -1 which reverts to default behavior of UE")]
  [int] $fps = -1,
  [Parameter(Mandatory = $False, HelpMessage = "downloadUri")]
  [String]$unrealApplicationDownloadUri = "",
  [Parameter(Mandatory = $False, HelpMessage = "STUN Server Address")]
  [String]$stunServerAddress = "",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Address")]
  [String]$turnServerAddress = "",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Username")]
  [String]$turnUsername = "",
  [Parameter(Mandatory = $False, HelpMessage = "TURN Server Password")]
  [String]$turnPassword = ""
)

$StartTime = Get-Date

#####################################################################################################
#base variables
#####################################################################################################
$logsfolder = "c:\gaming\logs"
$logoutput = $logsfolder + '\ue4-upgradeVMSS-output-' + (get-date).ToString('MMddyyhhmmss') + '.txt'
$baseFolder = "c:\Unreal_"
$folder = $baseFolder + $version + "\"

$folderNoTrail = $folder
if ($folderNoTrail.EndsWith("\")) {
  $l = $folderNoTrail.Length - 1
  $folderNoTrail = $folderNoTrail.Substring(0, $l)
}

#####################################################################################################
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force
New-Item -Path $logsfolder -ItemType directory -Force
function logmessage() {
  $logmessage = $args[0]
  $MessageTime = Get-Date -Format "[MM/dd/yyyy HH:mm:ss]"

  $output = "$MessageTime - $logmessage"
  Add-Content -Path $logoutput -Value $output
}

### FIND THE PREVIOUS VERSION ###
$versionPrev = -1
for($i=$version; $i -ge 1; $i--) {
    if ( (Get-ChildItem ($baseFolder+$i) | Measure-Object).Count -ne 0) {
        $versionPrev = $i
        break;
    }
}
logmessage $versionPrev
if (($versionPrev -lt 1) -or ($versionPrev -eq $version))
{
  logmessage "No previous version found or new version equals an already existing version. ABORTING."
  break
}

### READ PARAMS AND MERGE PASSED PARAMS IN ###
$paramsFolder = "C:\CSE-params"
$config = (Get-Content  "$paramsFolder\params.json" -Raw) | ConvertFrom-Json
$config.instancesPerNode = $instancesPerNode
$config.resolutionWidth = $resolutionWidth
$config.resolutionHeight = $resolutionHeight
$config.pixelstreamingApplicationName = $pixelstreamingApplicationName
$config.fps = $fps
$config.unrealApplicationDownloadUri = $unrealApplicationDownloadUri
$config.turnServerAddress = $turnServerAddress
$config.stunServerAddress = $stunServerAddress
$config.turnUsername = $turnUsername
$config.turnPassword = $turnPassword

$enableHttps_bool = (&{If($config.enableHttps -eq "True") {$true} Else {$false}})
$userModifications_bool = (&{If($config.userModifications -eq "True") {$true} Else {$false}})
$enableAuthentication_bool = (&{If($config.enableAuthentication -eq "True") {$true} Else {$false}})
# Just read the enable pixel streaming setting from params.json. Don't update it. 
$enablePixelStreamingCommands_bool = (&{If($config.allowPixelStreamingCommands -eq "True") {$true} Else {$false}})

### SET BASE VARS ###
$vmServiceFolder = "$folderNoTrail\WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers\SignallingWebServer"
$vmWebServicesFolder = "$folderNoTrail\WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers\"
$executionfilepath = "$folderNoTrail\scripts\startVMSS.ps1"

$base_name = $config.vmssName.Substring(0, $config.resourceGroupName.IndexOf("-"))
$akv = "akv-$base_name"

### GET SOME VARS FROM THE PREVIOUS VERSION ###
$folderPrev = $baseFolder + $versionPrev + "\"
$vmServiceFolderPrev = $vmServiceFolder.Replace($folder, $folderPrev)
$vmssConfigJsonPrev = (Get-Content  ($vmServiceFolderPrev+"\config.json") -Raw) | ConvertFrom-Json
$pixelstreamingApplicationNamePrev = $vmssConfigJsonPrev.unrealAppName

logmessage "Previous Version: $versionPrev"
logmessage "Previous Version's 3D App Name: $pixelstreamingApplicationNamePrev"

### UPDATE THE FIREWALL ###
logmessage "Starting BE Setup at:$StartTime"
logmessage "Disabling Windows Firewalls started"
For ($i=1; $i -le $config.instancesPerNode; $i++) {
    $newPublicPort = $config.signallingserverPublicPortStart + $i - 1;
    New-NetFirewallRule -DisplayName "SignallingServer-IB-$newPublicPort" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $newPublicPort
}
logmessage "Disabling Windows Firewalls complete"

logmessage "Creating: $folder"
New-Item -Path $folder -ItemType directory

logmessage "Cloning code process from Git Start"
$wsFolder = ($folder + "WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers")
$downloadMsImprovedWebserversFile = "msImprovedWebservers.zip"
$downloadMsPrereqsFile = "msPrereqs.zip"
$downloadUA4Destination = "c:\tmp\unreal_" + $version +".zip"
$downloadMsImprovedWebserversDestination = ("c:\tmp\" + $downloadMsImprovedWebserversFile)
$downloadMsPrereqsDestination = ("c:\tmp\" + $downloadMsPrereqsFile)
$ProgressPreference = 'SilentlyContinue'
$retries = 0
$downloadSuccess = $false
$preExistingAppFolder = "c:\App"

if ( (Get-ChildItem $folderNoTrail | Measure-Object).Count -eq 0) 
{
  do {
    try {
      if (Test-Path -Path $preExistingAppFolder)
      {
        logmessage "Checking if the deployment was done via custom Image"
        #1. Check if the app is extracted already. Assuming we have C:\App\AppName(generally WindowsNoEditor)\Actual Extracted App
        $appFolderName = (Get-ChildItem $preExistingAppFolder -directory | Select-Object -First 1)
        if ($null -ne $appFolderName) {
          logmessage "App is already present in extracted format"
          Copy-Item -Path $appFolderName.FullName -Destination $folder -Recurse -Exclude "*.zip"
          logmessage "Setting extracted app to true to skip the download and extraction of the app"
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
        }
      } 
      else 
      {
        logmessage "Attempt to download: ", $config.unrealApplicationDownloadUri

        # Check if the user has passed a URI otherwise just skip it. 
        Start-BitsTransfer -Source $config.unrealApplicationDownloadUri -Destination $downloadUA4Destination 

        logmessage "File Size: ", (Get-Item -Path $downloadUA4Destination).Length
        if ( (Get-Item -Path $downloadUA4Destination).Length -gt 0 ) {
          logmessage "Reset download success to True to exit the loop"
          $downloadSuccess = $true
          logmessage "Extracting the downloaded zip file"
          7z x $downloadUA4Destination ("-o"+$folder) -bd
        } else {
          logmessage "Set download success to False to keep retrying"
          Start-Sleep -Seconds 60
          $downloadSuccess = $false
        }
      }
    }
    catch 
    {
      logmessage ("Something went wrong while downloading the zip file: $_")
      $retries++
      Start-Sleep -Seconds 5
    }
  } until ($downloadSuccess -or ($retries -ge 10))
}
else 
{
  logmessage "Unreal Folder was not Empty. ABORTING."
  break
}
# Rename the application folder name to WindowsNoEditor
$appFolderName = (Get-ChildItem $folder -directory | Select-Object -First 1).Name

#Code to find the application Name
$command = (Get-ChildItem -Recurse -Depth 3 -Path $folderNoTrail\$appFolderName -Filter "*.exe"  -Exclude "UE*PrereqSetup*.exe","CrashReporter*.exe","EpicWebHelper.exe" | Select-Object -First 1)
$exeAppName = $command.Basename
logmessage "The first exe name found in the directory structure: ", $exeAppName
$config.pixelstreamingApplicationName =  $exeAppName
$engineIniFilepath = "$folderNoTrail\WindowsNoEditor\" + $config.pixelstreamingApplicationName + "\Saved\Config\WindowsNoEditor"
logmessage "Remove this once verified: ", $config.pixelstreamingApplicationName
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

#Add FPS to Engine.ini if FPS is set to > -1
if ($config.fps -gt -1) {
  logmessage "Start - Adding FPS config to Engine.ini"
  try 
  {
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
    logmessage $_
  }
}

logmessage "Starting Loop"
$tasksToStart = @()
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
      logmessage "Failed to set path to : $SSFolder"
      break
    }
  
    logmessage "Writing paramters from extension: $SSFolder"

    $vmssConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
    logmessage "current config : $vmssConfigJson"

    logmessage "Current remove: ", $config.pixelstreamingApplicationName

    $vmssConfigJson.resourceGroup = $config.resourceGroupName
    $vmssConfigJson.subscriptionId = $config.subscriptionId
    $vmssConfigJson.virtualMachineScaleSet = $config.vmssName
    $vmssConfigJson.appInsightsInstrumentationKey = $config.appInsightsInstrumentationKey
    $vmssConfigJson.matchmakerAddress = $config.mm_lb_fqdn
    $vmssConfigJson.matchmakerPort = $config.matchmakerInternalPort
    $vmssConfigJson.publicIp = $thispublicip
    $vmssConfigJson.signallingServerPort = ($config.signallingserverPublicPortStart + ($instanceNum - 1))
    $vmssConfigJson.streamerPort = ($config.streamingPort + ($instanceNum - 1))
    $vmssConfigJson.unrealAppName = $config.pixelstreamingApplicationName
    $vmssConfigJson.matchmakerInternalApiAddress = $config.matchmakerInternalApiAddress
    $vmssConfigJson.matchmakerInternalApiPort = $config.matchmakerInternalApiPort
    $vmssConfigJson.region = $config.deploymentLocation
    $vmssConfigJson.version = $version
    $vmssConfigJson.enableHttps = $enableHttps_bool
    $vmssConfigJson.enableAuthentication = $enableAuthentication_bool
    $vmssConfigJson.customDomainName = $config.customDomainName
    $vmssConfigJson.dnsConfigRg = $config.dnsConfigRg
    $vmssConfigJson.stunServerAddress = $config.stunServerAddress
    $vmssConfigJson.turnServerAddress = $config.turnServerAddress
    $vmssConfigJson.turnUsername = $config.turnUsername
    $vmssConfigJson.turnPassword = $config.turnPassword
    $vmssConfigJson.allowPixelStreamingCommands = $config.allowPixelStreamingCommands

    $vmssConfigJson | ConvertTo-Json | set-content "config.json"
    $vmssConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
    logmessage $vmssConfigJson

    logmessage "Writing parameters from extension complete. Updated config : $vmssConfigJson"
  }
  catch {
    logmessage "Exception: ", $_
  }
  
  logmessage "Creating a job schedule "

  $trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:10
  try {
    $User = "NT AUTHORITY\SYSTEM"
    $PS = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ("-executionpolicy bypass -noprofile -file $executionfilepath $instanceNum " + $config.streamingPort + " " + $config.resolutionWidth + " " + $config.resolutionHeight + " """ +  $config.pixelstreamingApplicationName + """ " + $version + " " + $enablePixelStreamingCommands_bool)
    Register-ScheduledTask -Trigger $trigger -User $User -TaskName $taskName -Action $PS -RunLevel Highest -AsJob -Force
  }
  catch {
    logmessage "Exception occured while starting the Exe file: ", $_
  }
  
  logmessage "Creating a job schedule complete"
  az login --identity
  az account set --subscription $config.subscriptionId

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
        $certs = (az keyvault secret list --vault-name $akv --query "[?starts_with(name, 'https-')]") | ConvertFrom-Json
        if ($certs.Length -eq 2) 
        {
          logmessage "Starting certificate download"
          #download the private key
          $cert = az keyvault secret show --vault-name $akv -n "https-privatekey" --query "value" | ConvertFrom-Json
          $file = "client-key.pem"
          $decodedText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cert))
          New-Item -Path $file -Type File -Value $decodedText -Force
  
          # download the public key
          $cert = az keyvault secret show --vault-name $akv -n "https-publickey" --query "value" | ConvertFrom-Json
          $file = "client-cert.pem"
          $decodedText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cert))
          New-Item -Path $file -Type File -Value $decodedText -Force
          
          logmessage "Certificate download was successful so setting certAvailable to True"
          $certAvailable = $true
        }
      } catch {
        logmessage "Something went wrong while fetching certificates ", $_
        $retries++
        Start-Sleep -Seconds 10
      }
    } until ($certAvailable -or ($retries -ge 10))
  }
  $tasksToStart += $taskName
}

### Remove Scheduled tasks ###
logmessage "Remove the Scheduled Tasks from the previous version"
try {
    for($i=1; $i -le 4; $i++)
    {
      $taskName = "StartVMSS_" + $versionPrev + "_" +$i
      $sti = Get-ScheduledTask $taskName
      if($null -ne $sti) {
        logmessage "Deleting Scheduled Task $taskName"
        Unregister-ScheduledTask -Taskname $taskName -Confirm:$false
      }
      else
      {
        logmessage "$taskName does not exist"
      }
    }
}
catch
{
  logmessage "ERROR:::An error occurred when deleting the Scheduled Tasks from version: $versionPrev"
  logmessage $_
}

### KILL EXISTING NODE AND 3D UE4 APP ###
try {
  # Then kill the UA4 app
  logmessage "Kill existing Unreal processes"
  $processes = Get-Process ($pixelstreamingApplicationNamePrev + "*")
  logmessage ("Number of Unreal processes: " + $processes.Count)
  if($processes.Count -gt 0)
  {
    foreach($process in $processes)
    {
      $process | Stop-Process -Force
    }
  }
  else
  {
    logmessage $pixelstreamingApplicationNamePrev " + not running when trying to restart"
  }

  # First kill the Node process so it deregisters from the MM so no traffic is sent over anymore...
  logmessage "Kill existing Node processes"
  $processes = Get-Process ("node")
  logmessage ("Number of Node processes: " + $processes.Count)
  if($processes.Count -gt 0)
  {
    # The Node code swawns a child process to run this Powershell. We need to kill this process at the end, otherwise the execution of this PS will stop too soon.
    # Therefore we are fetching the ParentProcessId from the current PS ProcessID ($PID), so when we loop through the Node processes to kill them, we make sure we
    # kill the one that is executing the PS last
    $nodeProcessId = (gwmi win32_process | ? processid -eq  $PID).parentprocessid
    $currentlyExecutingNodeProcess = $null
    foreach($process in $processes)
    {
      if($process.Id -ne $nodeProcessId) {
        $process | Stop-Process -Force
      } else {
        $currentlyExecutingNodeProcess = $process
      }
    }

    logmessage ("TasksToStart Length: " + $tasksToStart.Length)
    for($i=0; $i -lt $tasksToStart.Length; $i++) {
      $taskName = $tasksToStart[$i]
      #execute the scheduled task to start the processes this time
      logmessage ("Start Task: " + $taskName)
      Start-ScheduledTask -TaskName "$taskName" -AsJob
    }

    if($null -ne $currentlyExecutingNodeProcess) {
      logmessage "Killing last NodeJS process which will stop the execution of the PS"
      $currentlyExecutingNodeProcess | Stop-Process -Force
    }
  }
  else
  {
    logmessage "NodeJS not running when trying to restart"
  }
}
catch
{
  logmessage "ERROR:::An error occurred when killing process: "
  logmessage $_
}
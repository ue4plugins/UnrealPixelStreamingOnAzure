# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
Param (
  [Parameter(Mandatory = $True, HelpMessage = "subscription id from terraform")]
  [int]$version = "",
  [Parameter(Mandatory = $false, HelpMessage = "Desired instances of 3D apps running per VM, default 1")]
  [int] $instancesPerNode = 1,
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
  [Parameter(Mandatory = $False, HelpMessage = "downloadUri")]
  [String]$unrealApplicationDownloadUri = ""
)

#####################################################################################################
#base variables
#####################################################################################################
$logsfolder = "c:\gaming\logs"
$logoutput = $logsfolder + '\ue4-upgradeMM-output-' + (get-date).ToString('MMddyyhhmmss') + '.txt'
$baseFolder = "c:\Unreal_"
$folder = $baseFolder + $version + "\"
$taskName = "StartMMS_"

$folderNoTrail = $folder
if ($folderNoTrail.EndsWith("\")) {
  $l = $folderNoTrail.Length - 1
  $folderNoTrail = $folderNoTrail.Substring(0, $l)
}

### FIND THE PREVIOUS VERSION ###
$versionPrev = -1
for($i=$version; $i -ge 1; $i--) {
    if ( (Get-ChildItem ($baseFolder+$i) | Measure-Object).Count -ne 0) {
        $versionPrev = $i
        break;
    }
}
Write-Output $versionPrev
if (($versionPrev -lt 1) -or ($versionPrev -eq $version))
{
  Write-Output "No previous version found or new version equals an already existing version. ABORTING."
  break
}

### READ PARAMS AND MERGE PASSED PARAMS IN ###
$paramsFolder = "C:\CSE-params"
$config = (Get-Content  "$paramsFolder\params.json" -Raw) | ConvertFrom-Json
$config.instancesPerNode = $instancesPerNode
$config.enableAutoScale = $enableAutoScale
$config.instanceCountBuffer = $instanceCountBuffer
$config.percentBuffer = $percentBuffer
$config.minMinutesBetweenScaledowns = $minMinutesBetweenScaledowns
$config.scaleDownByAmount = $scaleDownByAmount
$config.minInstanceCount = $minInstanceCount
$config.maxInstanceCount = $maxInstanceCount
$config.unrealApplicationDownloadUri = $unrealApplicationDownloadUri

$enableAutoScale_bool = (&{If($config.enableAutoScale -eq "True") {$true} Else {$false}})
$enableAuth_bool = (&{If($config.enableAuth -eq "True") {$true} Else {$false}})
$userModifications_bool = (&{If($config.userModifications -eq "True") {$true} Else {$false}})
$enableHttps_bool = (&{If($config.enableHttps -eq "True") {$true} Else {$false}})

### SET BASE VARS ###
$mmServiceFolder = "$folderNoTrail\WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers\Matchmaker"
$mmCertFolder = $mmServiceFolder + "\Certificates"
$executionfilepath = "$folderNoTrail\scripts\startMMS.ps1"

$base_name = $config.vmssName.Substring(0, $config.resourceGroupName.IndexOf("-"))
$akv = "akv-$base_name"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force

New-Item -Path $logsfolder -ItemType directory -Force
function logmessage() {
  $logmessage = $args[0]    
  $MessageTime = Get-Date -Format "[MM/dd/yyyy HH:mm:ss]"

  $output = "$MessageTime - $logmessage"
  Add-Content -Path $logoutput -Value $output
}

logmessage "Creating: $folder"
New-Item -Path $folder -ItemType directory

$wsFolder = ($folder + "WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers")
$downloadMsImprovedWebserversFile = "msImprovedWebservers.zip"
$downloadMsPrereqsFile = "msPrereqs.zip"
$downloadUA4Destination = "c:\tmp\unreal_" + $version +".zip"
$downloadMsImprovedWebserversDestination = ("c:\tmp\" + $downloadMsImprovedWebserversFile)
$downloadMsPrereqsDestination = ("c:\tmp\" + $downloadMsPrereqsFile)
$preExistingAppFolder = "c:\App"
$ProgressPreference = 'SilentlyContinue'

logmessage "Cloning code process from Git Start"
if ( (Get-ChildItem $folderNoTrail | Measure-Object).Count -eq 0) {
  try {
    #fetch and unzip the UE4 App + Webservers if the user made modification. If they did not make modifications we don't need to download the package on the MM as we will override the Webservers folder anywway
    if($userModifications_bool -eq $true) {
      logmessage "User modified MM and SS should be available so check if custom image is present before downloading from URI"
      if(Test-Path -Path $preExistingAppFolder) {
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
        $unrealApplicationDownloadUri = $config.unrealApplicationDownloadUri.replace('%26', '&')
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
  break
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
$mmConfigJson.enableAuth = $enableAuth_bool
$mmConfigJson.storageConnectionString = $config.storageConnectionString
$mmConfigJson.region = $config.deploymentLocation
$mmConfigJson.version = $version
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

logmessage "Az Login"
az login --identity
logmessage "Az Set Subscription"
az account set --subscription $config.subscriptionId

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
  Register-ScheduledTask -Trigger $trigger -User $User -TaskName ($taskName + $version) -Action $PS -RunLevel Highest -Force 
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
Start-ScheduledTask -TaskName "StartMMS" -AsJob

### Remove Scheduled tasks ###
logmessage "Remove the Scheduled Tasks from the previous version"
try {
        $prevTaskName = ($taskName + $versionPrev)
        $sti = Get-ScheduledTask $prevTaskName
        if($sti -ne $null) {
            logmessage "Deleting Scheduled Task $prevTaskName"
            Unregister-ScheduledTask -Taskname $prevTaskName -Confirm:$false
        }
        else
        {
            logmessage "$prevTaskName does not exist"
        }
}
catch 
{
    logmessage "ERROR:::An error occurred when deleting the Scheduled Tasks from version: $versionPrev"
    logmessage $_
}

### KILL EXISTING NODE  APP ###
try {
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

        $newTaskName = ($taskName + $version)
        #execute the scheduled task to start the processes this time
        logmessage ("Start Task: " + $newTaskName)
        Start-ScheduledTask -TaskName $newTaskName -AsJob

        if($currentlyExecutingNodeProcess -ne $null) {
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

$EndTime = Get-Date
logmessage "Completed at: $EndTime"

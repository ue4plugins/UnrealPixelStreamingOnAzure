# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

[CmdletBinding()]
Param (
   [Parameter(Position=0, Mandatory=$false, HelpMessage = "Current instance number for a Signlaing Server folder, default 1")]
   [int] $instanceNum = 1,
   [Parameter(Position=1, Mandatory=$false, HelpMessage = "The streaming port start for multiple instances, default 8888")]
   [int] $streamingPort = 8888,
   [Parameter(Position=2, Mandatory=$false, HelpMessage = "The resolution width of the 3D app, default 1920")]
   [int] $resolutionWidth = 1920,
   [Parameter(Position=3, Mandatory=$false, HelpMessage = "The resolution height of the 3D app, default 1080")]
   [int] $resolutionHeight = 1080,
   [Parameter(Position=4, Mandatory=$false, HelpMessage = "The name of the 3D app, default PixelStreamingDemo")]
   [string] $pixelstreamingApplicationName = "PixelStreamingDemo",
   [Parameter(Position=5, Mandatory=$false, HelpMessage = "The version of the 3D app")]
   [int] $version = 1,
   [Parameter(Position=6, Mandatory=$false, HelpMessage = "Option to enable PixelStreaming commands")]
   [string] $enablePixelStreamingCommands_bool = "false"
)

#####################################################################################################
#base variables
#####################################################################################################
$PixelStreamerFolder = "C:\Unreal_" + $version + "\WindowsNoEditor\"
$PixelStreamerExecFile = $PixelStreamerFolder + $pixelstreamingApplicationName + ".exe"
$vmServiceFolder = $PixelStreamerFolder + "Engine\Source\Programs\PixelStreaming\WebServers\SignallingWebServer"
if($instanceNum -gt 1) {
   $vmServiceFolder = $vmServiceFolder + $instanceNum
}

$logsbasefolder = "C:\gaming"
$logsfolder = "c:\gaming\logs"
$logoutput = $logsfolder + '\ue4-startVMSS-output' + (get-date).ToString('MMddyyhhmmss') + '.txt'
$stdout = $logsfolder + '\ue4-signalservice-stdout' + (get-date).ToString('MMddyyhhmmss') + '.txt'
$stderr = $logsfolder + '\ue4-signalservice-stderr' + (get-date).ToString('MMddyyhhmmss') + '.txt'

#pixelstreamer arguments
$port = $streamingPort + ($instanceNum-1)
$audioMixerArg = "-AudioMixer"
$streamingIPArg = "-PixelStreamingIP=localhost"
$streamingPortArg = "-PixelStreamingPort=" + $port
$renderOffScreenArg = "-RenderOffScreen"
$resolutionWidthArg = "-ResX=" + $resolutionWidth
$resolutionHeightArg = "-ResY=" + $resolutionHeight
$allowPixelStreamingCommandsArg = (&{If($enablePixelStreamingCommands_bool -eq "True") {"-AllowPixelStreamingCommands"} Else {""}})

#####################################################################################################

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force

#create a log folder if it does not exist
if (-not (Test-Path -LiteralPath $logsfolder)) {
   Write-Output "creating directory :" + $logsfolder
   $fso = new-object -ComObject scripting.filesystemobject
   if (-not (Test-Path -LiteralPath $logsbasefolder)) {
      $fso.CreateFolder($logsbasefolder)
      Write-Output "created gaming folder"
   }
   $fso.CreateFolder($logsfolder)
}
else {
   Write-Output "Path already exists :" + $logsfolder
}

function logmessage() {
  $logmessage = $args[0]    
  $MessageTime = Get-Date -Format "[MM/dd/yyyy HH:mm:ss]"

  $output = "$MessageTime - $logmessage"
  Add-Content -Path $logoutput -Value $output
}

Set-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe" -Scope Global
Set-Alias -Name node -Value "$Env:ProgramFiles\nodejs\node.exe" -Scope Global
Set-Alias -Name npm -Value "$Env:ProgramFiles\nodejs\node_modules\npm" -Scope Global

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

logmessage "startingVMSS"

if (-not (Test-Path -LiteralPath $PixelStreamerFolder)) {
   logmessage "PixelStreamer folder: $PixelStreamerFolder doesn't exist"
}

Set-Location -Path $PixelStreamerFolder 
logmessage "current folder: $PixelStreamerFolder"

if (-not (Test-Path -LiteralPath $PixelStreamerExecFile)) {
   logmessage"PixelStreamer Exec file: $PixelStreamerExecFile doesn't exist" 
}

try {
   logmessage "PixelStreamerExecFile: $PixelStreamerExecFile"
   & $PixelStreamerExecFile $audioMixerArg $streamingIPArg $streamingPortArg $renderOffScreenArg -WinX=0 -WinY=0 $resolutionWidthArg $resolutionHeightArg -Windowed -ForceRes $allowPixelStreamingCommandsArg
   logmessage "started: $PixelStreamerExecFile"
}
catch {
   logmessage "Error occurred while starting Pixel streaming file " + $_
}
finally {
   $error.clear()
}

if (-not (Test-Path -LiteralPath $vmServiceFolder)) {
   logmessage "SignalService folder: $vmServiceFolder doesn't exist" 
}

Set-Location -Path $vmServiceFolder 
logmessage "current folder: $vmServiceFolder"

$vmssConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
logmessage "Config.json: $vmssConfigJson"

try {
   $resourceGroup = $vmssConfigJson.resourceGroup
   $vmssName = $vmssConfigJson.virtualMachineScaleSet
   $customDomainName = $vmssConfigJson.customDomainName
   $dnsConfigRg = $vmssConfigJson.dnsConfigRg
   $base_name = $vmssName.Substring(0, $resourceGroup.IndexOf("-"))

   logmessage "RG Name: $resourceGroup"
   logmessage "VMSS Name: $vmssName"
   logmessage "CustomDomainName: $customDomainName"
   logmessage "dnsConfigRg: $dnsConfigRg"

   $privateIpAddress = (
      Get-NetIPConfiguration |
      Where-Object {
         $_.IPv4DefaultGateway -ne $null -and
         $_.NetAdapter.Status -ne "Disconnected"
      }
   ).IPv4Address.IPAddress

   logmessage "Private IP Address: $privateIpAddress"

   az login --identity

   $publicIpResourceId = az vmss nic list --vmss-name $vmssName -g $resourceGroup --query "[].ipConfigurations[?privateIpAddress=='$privateIpAddress'].[publicIpAddress.id][0][0]" | ConvertFrom-Json
   logmessage "Public IP ResourceID: $publicIpResourceId"
   $publicIpInfo = az vmss list-instance-public-ips -n $vmssName -g $resourceGroup --query "[?id=='$publicIpResourceId'].[ipAddress,dnsSettings.domainNameLabel,dnsSettings.fqdn]" | ConvertFrom-Json
   $publicIp = $publicIpInfo[0][0]
   $domainNameLabel = $publicIpInfo[0][1]
   $fqdn = $publicIpInfo[0][2]

   logmessage "Public IP Address: $publicIp"
   logmessage "Current DomainNameLabel: $domainNameLabel"
   logmessage "Current FQDN: $fqdn"

   if ($vmssConfigJson.customDomainName -ne "") {
      $domainNameLabel = $domainNameLabel.replace(".", "-")
      $fqdn = $domainNameLabel + "." + $customDomainName
      logmessage "New FQDN: $fqdn"
      
      az network dns record-set a create -n $domainNameLabel -g $dnsConfigRg -z $customDomainName --metadata "randomString=$base_name"
      az network dns record-set a add-record -a $publicIp -n $domainNameLabel -g $dnsConfigRg -z $customDomainName
   }
   
   $env:VMFQDN = $fqdn;
   logmessage "Success in getting FQDN: " + $fqdn;
}
catch {
   logmessage "Error getting FQDN for VM: " + $_
}

start-process "cmd.exe" "/c .\runAzure.bat" -RedirectStandardOutput $stdout -RedirectStandardError $stderr -ErrorVariable ProcessError

if ($ProcessError) {
   logmessage "Error in starting Signal Service"
}
else {
   logmessage "Started vmss sucessfully runAzure.bat" 
}
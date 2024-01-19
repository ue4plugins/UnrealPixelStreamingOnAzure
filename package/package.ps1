Param (
  [String] $releaseFolder = ('release_' + (get-date).ToString('MMddyyhhmmss')),
  [Boolean] $buildDashboard = $true
)

$tempFolder = "temp"
New-Item -Path $releaseFolder -ItemType directory -Force

Set-Location $releaseFolder

New-Item -Path $tempFolder -ItemType directory -Force

Set-Location $tempFolder

az bicep build --file ..\..\..\arm\mainTemplate.bicep --outfile ..\..\..\arm\mainTemplate.json

Copy-Item "..\..\..\arm\createUiDefinition.json"
Copy-Item "..\..\..\arm\mainTemplate.json"
Copy-Item "..\..\..\arm\mp_mm_setup.ps1"
Copy-Item "..\..\..\arm\mp_ss_setup.ps1"

New-Item -Path "webservers" -ItemType directory -Force
Copy-Item "..\..\..\Unreal\Engine\Source\Programs\PixelStreaming\WebServers\Matchmaker" -Destination ".\webservers" -Recurse
Copy-Item "..\..\..\Unreal\Engine\Source\Programs\PixelStreaming\WebServers\SignallingWebServer" -Destination ".\webservers" -Recurse

New-Item -Path "prereqs" -ItemType directory -Force
Copy-Item "..\..\..\scripts" -Destination ".\prereqs" -Recurse -Force

New-Item -Path "dashboard" -ItemType directory -Force
Copy-Item "..\..\..\Unreal\Engine\Source\Programs\PixelStreaming\WebServers\Dashboard\*" -Destination ".\dashboard" -Recurse
Copy-Item "..\..\..\Unreal\Engine\Source\Programs\PixelStreaming\WebServers\Matchmaker\modules\storagelayer.js" -Destination ".\dashboard\server\modules" -Recurse
Copy-Item "..\..\..\Unreal\Engine\Source\Programs\PixelStreaming\WebServers\Matchmaker\modules\userAuthLayer.js" -Destination ".\dashboard\server\modules" -Recurse

if($buildDashboard -eq $true) {
  Set-Location "dashboard"
  npm install
  npm run build
  Copy-Item ".\build" -Destination ".\server" -Recurse
  Set-Location "..\"
}

Compress-Archive -Path ".\webservers\*" -DestinationPath ".\msImprovedWebservers.zip"
Compress-Archive -Path ".\prereqs\*" -DestinationPath ".\msPrereqs.zip"
Compress-Archive -Path ".\dashboard\server\*" -DestinationPath ".\msDashboard.zip"

Remove-Item -Path "webservers" -Recurse
Remove-Item -Path "prereqs" -Recurse
Remove-Item -Path "dashboard" -Recurse

Set-Location "..\"
Compress-Archive -Path ".\temp\*" -DestinationPath ".\marketplacePackage.zip"
Remove-Item -Path $tempFolder -Recurse
Set-Location "..\"
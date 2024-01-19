# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# This is optionally used by the Signaling Server to reset the UE4 exe when a user disconnects
[CmdletBinding()]
Param (
    [Parameter(Position=0, Mandatory=$true, HelpMessage = "3D Application name")]
    [string] $unrealAppName,
    [Parameter(Position=1, Mandatory=$true, HelpMessage = "The streaming port of the 3D App name we're trying to restart")]
    [int] $streamingPort
)

$logsfolder = "c:\gaming\logs"
$logoutput = $logsfolder + '\vmss-clientdisconnected-output' + (get-date).ToString('MMddyyhhmmss') + '.txt'

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force

function logmessage() {
    $logmessage = $args[0]    
    $MessageTime = Get-Date -Format "[MM/dd/yyyy HH:mm:ss]"

    $output = "$MessageTime - $logmessage"
    Add-Content -Path $logoutput -Value $output
}

try 
{
    #Two UE4 processes are spun up so we close both of them here, and only restart the one that is the original parent .exe
    logmessage "Unreal app name received: $unrealAppName"
    $processes = Get-Process ($unrealAppName + "*")
    logmessage "Start - Unreal processes: ", $processes.Count
    $finalPath = ""
    $finalArgs = ""
    if($processes.Count -gt 0)
    {
        foreach($process in $processes)
        {
            $path = $process.Path
            $procID = $process.Id
            $cmdline = (Get-WMIObject Win32_Process -Filter "Handle=$procID").CommandLine

            if($cmdline.Contains("-PixelStreamingPort="+$streamingPort))
            {
                if($cmdline -Match (" " + $unrealAppName + " "))
                {
                    $processToKill = $process
                    logmessage "processToKill: $processToKill"
                }
                
                #Only grab the original parent pixel streaming unreal app, not the child one, so we can restart it
                if($cmdline -notmatch (" " + $unrealAppName + " "))
                {
                    $finalPath = $path
                    $finalArgs = $cmdline.substring($cmdline.IndexOf("-AudioMixer"))
                    logmessage "finalPath: $finalPath"
                    logmessage "finalArgs: $finalArgs"
                }
            }
        }
        
        if($null -ne $processToKill)
        {
            logmessage "Shutting down UE4 app: ", $processToKill.Path
            try 
            {
                $processToKill | Stop-Process -Force
            }
            catch 
            {
                logmessage "ERROR:::An error occurred when stopping process: ", $_
                try 
                {
                    Start-Sleep -Seconds 1
                    
                    $processToKill.Kill()
                    $processToKill.WaitForExit(3000)
                }
                catch 
                {
                    logmessage "ERROR:::An error occurred when killing process: ", $_
                }
            }
            Start-Sleep -Seconds 1
        } 
        else {
            logmessage "Process to kill is null so skipping the process kill/stop stage"
        }    
    }
    else
    {
        logmessage $unrealAppName, " not running when trying to restart"
    }

    try 
    {
        Start-Sleep -Seconds 5
        $startProcess = $true
        logmessage "Testing for unrealAppName: $unrealAppName"
        $newProcesses = Get-Process ($unrealAppName + "*")
        logmessage "After kill - Unreal processes: ", $newProcesses.Count
        if(($null -ne $newProcesses) -and ($newProcesses.Count -gt 0))
        {   
            foreach($process in $newProcesses)
            {
                $procID = $process.Id
                $cmdline = (Get-WMIObject Win32_Process -Filter "Handle=$procID").CommandLine

                if($cmdline.Contains("-PixelStreamingPort="+$streamingPort))
                {
                    $startProcess = $false
                    logmessage "Setting start process to false because the process exists already"
                    break
                }
            }
        }

        if($startProcess -eq $true)
        {   
            logmessage "Request to start the process "
            logmessage "finalPath: $finalPath"
            logmessage "finalArgs: $finalArgs"
            logmessage "Starting Process"
            #Start the final application if not already restarted
            Start-Process -FilePath $finalPath -ArgumentList $finalArgs
        }

        Start-Sleep -Seconds 5
        logmessage "After restart - AppName: $unrealAppName"
        $newProcesses = Get-Process ($unrealAppName + "*")
        logmessage "After restart - Unreal processes: ", $newProcesses.Count
    }
    catch 
    {
        logmessage "ERROR:::An error occurred when starting the process: ", $_
    }
}
catch 
{
    logmessage "ERROR:::An error occurred:", $_
}
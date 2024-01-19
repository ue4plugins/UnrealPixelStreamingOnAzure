build {

  sources = ["source.azure-arm.ws2022vhd"]

  # VM GPU Drivers Extension Install
  provisioner "shell-local" {
    inline = ["az vm extension set -g ${var.temp_resource_group_name} --vm-name ${var.temp_compute_name} --name NvidiaGpuDriverWindows --publisher Microsoft.HpcCompute --version 1.4 --settings '{}'"]
  }

  # Copy legal notice
  provisioner "file" {
    destination  = "C:\\Users\\Public\\Desktop\\"
    sources      = ["NOTICE.txt"]
    pause_before = "10m0s"
  }

  # Install tools
  provisioner "powershell" {
    inline = [
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))",
      "Write-Output 'TASK COMPLETED: Chocolatey installed'",

      "choco install -y git",
      "choco install -y git-lfs",
      "choco install -y nodejs",
      "choco install -y vcredist2017",
      "choco install -y azure-cli",
      "choco install -y azcopy",
      "choco install -y 7zip",
      "choco install -y microsoft-edge",
      "choco install -y directx",
      "Write-Output 'TASK COMPLETED: Chocolatey packages installed.'",

      "Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask | Out-Null",
      "Write-Output 'TASK COMPLETED: Server Manager disabled.'",

      "netsh advfirewall firewall add rule name='NetBIOS TCP Port 80' dir=in action=allow protocol=TCP localport=80",
      "Write-Output 'TASK COMPLETED: Pixel Streaming port configured.'"
    ]
  }

  # Restart VM
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"& {Write-Output 'Packer Build VM restarted'}\""
  }

  # Sysprep
  provisioner "powershell" {
    inline = [
      "while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /mode:vm /quiet /quit",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"
    ]
  }
}

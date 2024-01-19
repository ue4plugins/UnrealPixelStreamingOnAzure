# Azure Marketplace: Unreal Pixel Streaming

## WARNING and Welcome
This repository contains all the source code for the [Unreal Pixel Streaming](https://azuremarketplace.microsoft.com/en-US/marketplace/apps/epicgames.unreal-pixel-streaming?tab=overview) product from the Azure Marketplace, co-developed by Microsoft and Epic Games. It's a system that lets users upload a zipped file of their Unreal Engine project and automatically scale up pixel streaming instances across several regions around the world. Support and maintenance has ended for this project, so the code is being published and open-sourced in an effort to provide as much value as possible to the community after so much effort went into its development.

The code is being provided *as is*, and significant effort should be expected on the user's part to repurpose this repo for their own needs. It was architected very specifically to be an Azure Marketplace product, so a large portion of the code base and the majority of the documentation within is oriented around building VM images and packaging the Azure Application template in a very specific way. This project was not initially built and tested for broad public usage. You should expect there to be errors or undocumented steps. *Support of any kind is not provided*, but the hope is that it can help jumpstart your project or take it to the next level.

The repo is open-sourced under MIT license, so you are free to repurpose, modify, share, and even monetize the code as you wish.

The remainder of the README is in its original form from the developers.


## Contents

- [Overview](#overview)
- [Preparing for the Azure Marketplace](#preparing-for-the-azure-marketplace)
  - [Virtual Machine Image](#virtual-machine-image)
  - [Solution Template Package](#solution-template-package)
- [Contributing](#contributing)
- [Trademarks](#trademarks)
- [Local Deployment](#localdeployment)
- [Custom Image](#customImage)

## Overview

This repository contains the code and scripts needed to build and package the Azure Marketplace offer for Unreal Pixel Streaming. It consists of:

- [Packer templates](packer/README.md) for building the virtual machine image used in the Azure Resource Manager (ARM) templates.
- A set of [ARM templates](arm) and scripts for deploying Unreal Pixel Streaming in Azure.
- A custom [React dashboard](Unreal/Engine/Source/Programs/PixelStreaming/WebServers/Dashboard) to manage Pixel Streaming deployments.
- Customizations and enhancements to the Pixel Streaming servers ([Matchmaker](Unreal/Engine/Source/Programs/PixelStreaming/WebServers/Matchmaker) and [SignallingServer](Unreal/Engine/Source/Programs/PixelStreaming/WebServers/SignallingWebServer)) for auto-scaling and stability.

## Preparing for the Azure Marketplace

To publish the complete solution, you will need to publish two Marketplace offers:

- Azure Virtual Machine (VM) Offer. This is a public *hidden* offer that provides the virtual machine image.
- Azure Application - Solution Template Offer. This is a public offer that will deploy the solution using ARM templates. This offer is dependent on the publishing of the Azure Virtual Machine offer.

### Virtual Machine Image

For the VM offer, you will need to [build an image](packer/README.md) using the provided [Packer templates](packer). Once completed, Packer will output the location of the VHD.

[Generate a SAS address](https://docs.microsoft.com/en-us/azure/marketplace/azure-vm-get-sas-uri#generate-the-sas-address) for the generated VHD. You will need to provide this in the plan's technical configuration step.

### Solution Template Package

For the solution template offer, you will need to provide a zip package in the plan's technical configuration step. Use the PowerShell [packaging script](package/package.ps1) to generate this zip file (`marketplacePackage.zip`) in a release folder.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

## Local Deployment

The default image used in the /arm/modules/azuredeploy-regional.bicep is Core VM type so we don't need plan object in /arm/modules/azuredeploy-regional.bicep file however if you want to test with Azure VM offer type then look for the word "uncomment" in the file and uncomment the plan object. Also, replace the variables: mpDisk_publisher, mpDisk_offer, mpDisk_sku. 

Next step, is to use the replace the zip file link in /arm/createUiDefinition.parameters.json. Copy the complete path to an blob - zip file. Make sure to append SAS token at the end of it. Then replace all '&' with %26. Don't try to use encode function of the powershell as encodereplaces other special characters as well for instance '=' will be replaced with '%3D'. 

Change location if required. By default is eastUS. 

Copy config.json.tmpl and paste it as config.json. Location is the region where the main resource group will be deployed. Copy the link to a storage account. This is where the intermediate artifact will be uploaded. 

Next, open a command line and run the command deployDev.ps1 <new-resource-group-name>
  
Once the deployment is complete run deleteDeployment.ps1 <resource-group-name>


## Custom Image
When a user deploys a new Pixel Streaming project in Azure, they have the option of provided a custom VM image instead of the default one. A VM created as the signaling server can not be used to create a new image. If you don't have a VM already, you can use the following commands. Replace the variables in brackets <>. NOTE: Make sure to use the same subscription as the one you plan to use for the deployments of pixel streaming


>az group create --name < customImageGalleryRG > --location < location such as eastus >

>az sig create --resource-group < customImageGalleryRG > --gallery-name < customImageGallery >


>az sig image-definition create --resource-group < customImageGalleryRG > --gallery-name < customImageGallery > --gallery-image-definition < myCustomImageDefinition > --publisher < CustomPublisher > --offer < CustomOffer > --sku < CustomSku > --os-type Windows --hyper-v-generation V2


>az vm create --name < customVM > --resource-group < customImageGalleryRG > --image microsoft-agci-gaming:msftpixelstreaming:pixel-streamer-vm-plan:latest --admin-password < password > --admin-username < azureadmin > --location < eastus > --nsg-rule RDP --nsg custom-nsg


Now, login to the machine < customVM > using the password you mentioned in the above command and copy & paste your app as a zip or folder.The two options we support are:
  - C:\App\YourZipFile.zip
  
  or
  
  - C:\App\AppName\EntireAppdata something like C:\App\AppName(generally WindowsNoEditor)\Actual Extracted App
  
You can use this command to copy the zip or extract the zip file
  
>Invoke-WebRequest -Uri "Storage account link with SAS token" -OutFile "C:\App\app.zip"

or the following command (faster)

>$sas = "<sas token just the token to the container not the URL>" 

>az storage blob download --account-name < YourStgAccountName > --container-name < YouContainerName > --file "C:\App\YourZipFile.zip" --name "< Name of the blob ex YourApp.zip >" --sas-token """$sas"""


Do those sysprep step as mentioned [here](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/download-vhd?tabs=azure-portal). Go to portal, Stop the VM , wait for the VM to stop and then click capture. Wait for the Capture step to complete.
  
While Capturing make sure that you mention the regions properly. For instance, if you want pixel streaming to be supported in eastus and westus then image should also be present in those regions. On top of that, for every 20 VMs you can consider it to be equivalent of 1 replication count. You can increase the replication count as per your use case. 

Once the deployment is complete, now if you go to Pixel Streaming, you will see the created version in Custom Image drop down. 

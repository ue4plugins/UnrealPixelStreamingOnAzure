# Pixel Streaming VM Prerequisites VM Image

This folder contains the Packer templates for building the VM image used by the Pixel Streaming solution. The templates install the tools required to run Unreal Engine's Pixel Streaming technology.

## Prerequisites

To get started, you will need to complete the following:

1. Sign up for an [Azure account](https://azure.microsoft.com/) and subscription.
2. Install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
3. Install [Packer](https://www.packer.io/downloads).
4. Ensure you have quota for the `Standard_NV12s_v3` VM size. Refer to Microsoft's [documentation](https://docs.microsoft.com/en-us/azure/azure-portal/supportability/per-vm-quota-requests) to check quota or request quota increase for your subscription.

## Build

### Log into Azure

Log into your Azure account using the Azure CLI:
```
az login
```

Set the subscription:=
```
az account set -s NAME_OR_ID
```

### Create a Storage Account

Create a storage account where the VHDs will stored. Provide a unique name for the storage account (replace `psimages`).
```
az group create --name psimages-rg --location eastus
az storage account create -n psimages -g psimages-rg -l eastus --sku Standard_LRS
```

### Run Packer

Modify the `variables.pkr.hcl` file to fit your needs. You'll likely need to set the region, artifact_storage_account, and resource_group_name to match the storage account you created above. Set the `ExternalIP` to your machine's public IP.

Run Packer in this `packer` directory:
```
packer build .
```

Once completed, the output will look something like this

```
OSType: Windows
ManagedImageResourceGroupName: mydemo-rg
ManagedImageName: td1rg2-2022-11-17-0204
ManagedImageId: /subscriptions/abc123a1-6235-46c5-b560-az123ba2e771/resourceGroups/mydemo-rg/providers/Microsoft.Compute/images/td1rg2-2022-11-17-0204
ManagedImageLocation: eastus
```

In order to create .vhd file from this managedImage use the following commands. Document used: https://arsenvlad.medium.com/creating-vhd-azure-blob-sas-url-from-azure-managed-image-2be0e7c287f4

#Create Gallery
>az sig create --resource-group mydemo-rg --gallery-name mygallery1000

### Manual Step: Create shared image gallery image definition *"*Don't use this command*"*
The following command creates a Gen V1 image rather than V2, and it's included here only for legacy support. Instead of using this command, navigate to the gallery created above in the Azure Portal and use the UI for V2 version.

>az sig image-definition create --resource-group mydemo-rg --gallery-name mygallery1000 --gallery-image-definition image1000 --os-type Windows --publisher MicrosoftWindowsServer --offer WindowsServer --sku 2022-datacenter-azure-edition



#Create Image Version
myimage parameter will come from the manual step(aboove)
>az sig image-version create --resource-group mydemo-rg --gallery-name mygallery1000 --gallery-image-definition myimage --gallery-image-version 1.0.0 --target-regions eastus=1=standard_lrs --managed-image /subscriptions/abc123a1-6235-46c5-b560-az123ba2e771/resourceGroups/mydemo-rg/providers/Microsoft.Compute/images/td1rg2-2022-11-17-0204


#Create a disk
>az disk create --resource-group mydemo-rg --location eastus --name my-disk-from-image --gallery-image-reference /subscriptions/abc123a1-6235-46c5-b560-az123ba2e771/resourceGroups/mydemo-rg/providers/Microsoft.Compute/galleries/mygallery1000/images/myimage/versions/1.0.0

#Grant access to disk
>az disk grant-access --resource-group mydemo-rg --name my-disk-from-image --duration-in-seconds 36000 --access-level Read
--> return some md-soemthing URL . That is used in the last command

#Generate SAS 
>az storage container generate-sas --account-name mydemopsimages --name vhd --permissions acw --expiry "2022-12-12T00:00:00Z" 
--> output will look like "se=2022-12-12T00%3A00%3A00Z&sp=acw&sv=2021-06-08&sr=c&sig=<some sig>"

--Manual Step: Create vhd container in the storage account. In this case, mydemopsimages 

#Just do azcopy to complete the task
azcopy copy "https://md-abcdefxf2w3jv.z6.blob.storage.azure.net/rpmh3zkmqbmm/abcd?sv=2018-03-28&sr=b&si=b6eb97fc-0b70-4711-97f5-ddd2a6f97aff&sig=<some sig>" "https://mydemopsimages.blob.core.windows.net/vhd/myimage1.vhd?se=2022-12-12T00%3A00%3A00Z&sp=acw&sv=2021-06-08&sr=c&sig=<some sig>" --blob-type PageBlob

As a result you should have .vhd with you. 

Now, go to marketplace and create Azure VM offer types and use this .vhd file or just edit the existing the offer to use this Gen2 VHD file

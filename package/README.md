# PowerShell Scripts

This folder contains PowerShell scripts to help with packaging and test deployments.

### deployDev.ps1

Use this script to simulate a deployment of the solution template offer. It will package the ARM templates and scripts into a zip package, upload the zip file to a storage account, generate the artifact location and SAS, and deploy the resources using the ARM templates.

The following are required before running the script:

Azure Storage Account - use an existing Azure Storage account or [create one](https://docs.microsoft.com/en-us/azure/storage/common/storage-account-create). The connection string for this storage account is required in the `config.json` file (see below).

config.json - create a `config.json` file from [config.json.tmpl](config.json.tmpl). The following in that file are required: adminPass, location, storageConnectionString.

Azure CLI - install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) for your operating system. This is used in the PowerShell scripts.

To run the script, first sign in to your Azure account:
```
az login
```

Make any changes in the [createUiDefinition.parameters.json](../arm/createUiDefinition.parameters.json) file to fit your needs.

Then start the deployment, providing a resource group name:
```
.\deployDev.ps1 [GLOBAL_RESOURCE_GROUP_NAME]
```

### package.ps1

Use this script to generate an Azure Marketplace zip file. This will create a release folder containing the `marketplacePackage.zip` file. You can then upload this zip file in your plan's technical configuration step.

Before packaging, modify the VM image and partner ID to fit your needs:

- Set the publisher, offer and SKU matching your VM image in the [azuredeploy-regional.json](../arm/nestedtemplates/azuredeploy-regional.json#L152-L154) ARM template.
- Set the partner ID matching your offer in the [mainTemplate.json](../arm/mainTemplate.json#L158) ARM template. Replace the "name" with your partner ID.

Run the packaging script:
```
.\package.ps1
```

### deleteDeployment.ps1

Use this script to clean up test deployments. Provide the global resource group name and the script will find any resource groups tagged with the same random string value. The script will ask you to confirm before deleting the resource groups and DNS records.

```
.\deleteDeployment.ps1 [GLOBAL_RESOURCE_GROUP_NAME]
```
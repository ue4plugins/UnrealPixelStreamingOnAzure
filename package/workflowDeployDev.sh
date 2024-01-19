#!/bin/bash
echo $*
resourceGroup=$1
storageAccount=$2
artifactContainer=$3
location=$4
WORKING_DIR=$5
PIXEL_STREAMING_SAS=$6

echo "$PIXEL_STREAMING_SAS" 

suffix=$RANDOM
echo "::set-output name=suffix::$suffix"

cd "$WORKING_DIR" || exit

az group create \
    --name devops-test-$suffix \
    --location eastus

accountKey=$(az storage account keys list -g "$resourceGroup" -n "$storageAccount" | jq .[0].value)
outputUrl="https://$storageAccount.blob.core.windows.net/$artifactContainer/"

outputSas=$(az storage container generate-sas --only-show-errors --account-name "$storageAccount" --account-key "$accountKey" --name "$artifactContainer" --permissions dlrw --expiry 2023-12-01 -o tsv)
outputSas="?$outputSas"

az deployment group create \
    --name devops-test-$suffix \
    --resource-group devops-test-$suffix \
    --template-file mainTemplate.bicep \
    --parameters createUiDefinition.parameters.json \
    --parameters basics_adminPass="$ADMIN_PASS" \
    --parameters _artifactsLocation="$outputUrl" \
    --parameters _artifactsLocationSasToken="$outputSas" \
    --parameters basics_adminPass=Fake:$RANDOM \
    --parameters location="$location" \
    --parameters basics_pixelStreamZip="$PIXEL_STREAMING_SAS"

# "The following code will work only if the deployment was successful "
if [ $? -eq 0 ] 
then
    resourceGroup=devops-test-$suffix

    subscriptionId=$(az account show --query "id" --output tsv)
    randomString=$(az tag list --resource-id /subscriptions/$subscriptionId/resourcegroups/$resourceGroup --query "properties.tags.RandomString" --output tsv)

    dnsConfigRg='OtherAssets'
    dnsConfigZone='azurepixelstreaming.com'

    if [ ! -z "$randomString" ]
    then
        rgs=$(az group list --tag RandomString=$randomString --query "[].name" --output tsv)
        dns=$(az network dns record-set list -g $dnsConfigRg -z $dnsConfigZone --query "[?metadata.randomString=='$randomString']" --output tsv)
    fi

    for rg in $rgs 
    do 
        echo "Deleting..... $rg"
        $(az group delete -n $rg --no-wait -y)
    done

    echo "Starting deletion of DNS zones"
    for dnszone in $dns
    do
        if [ $dnszone.type = 'Microsoft.Network/dnszones/A' ]
        then
            $(az network dns record-set a delete -n $dnszone.name -g $dnsConfigRg -z $dnsConfigZone -y)
        fi
        if [ $dnszone.type = 'Microsoft.Network/dnszones/CNAME' ]
        then
            $(az network dns record-set cname delete -n $dnszone.name -g $dnsConfigRg -z $dnsConfigZone -y)
        fi
    done
else
   echo "Skipping delete"
   exit 1
fi
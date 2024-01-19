#!/bin/bash

if [ -z "$resourceGroup" ]; then
    resourceGroup=$0
    storageAccount=$1
    artifactContainer=$2
fi

ROOT="Unreal/Engine/Source/Programs/PixelStreaming/WebServers"

zip -r msPrereqs.zip ./scripts/* || exit 1
 
mkdir --parents webservers/Matchmaker/ \
&& mkdir --parents webservers/SignallingWebServer/ \
&& cp -R $ROOT/Matchmaker/* ./webservers/Matchmaker/ \
&& cp -R $ROOT/SignallingWebServer/* ./webservers/SignallingWebServer/ \
&& pushd ./webservers \
&& zip -r ../msImprovedWebservers.zip ./* \
&& popd || exit 1

accountKey=$(az storage account keys list -g "$resourceGroup" -n "$storageAccount" | jq .[0].value)

az storage blob upload \
    --container-name "$artifactContainer" \
    --account-name "$storageAccount" \
    --account-key "$accountKey" \
    --file msImprovedWebservers.zip \
    --name msImprovedWebservers.zip \
&& az storage blob upload \
    --container-name "$artifactContainer" \
    --account-name "$storageAccount" \
    --account-key "$accountKey" \
    --file msPrereqs.zip \
    --name msPrereqs.zip \
|| exit 1

rm -rf ./webservers
rm -rf ./dashboard

pushd arm \
&& az storage blob upload \
    --container-name "$artifactContainer" \
    --account-name "$storageAccount" \
    --account-key "$accountKey" \
    --file mp_mm_setup.ps1 \
    --name mp_mm_setup.ps1 \
&& az storage blob upload \
    --container-name "$artifactContainer" \
    --account-name "$storageAccount" \
    --account-key "$accountKey" \
    --file mp_ss_setup.ps1 \
    --name mp_ss_setup.ps1 \
&& popd || exit 1

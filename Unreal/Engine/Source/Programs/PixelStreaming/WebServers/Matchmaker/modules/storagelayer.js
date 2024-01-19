const { TableClient, odata } = require("@azure/data-tables");
const {
  BlobServiceClient,
  BlobSASPermissions,
} = require("@azure/storage-blob");

const tableName = "admin";
const partitionKey = "admin";
const containerName = "zips";
const uploadContainerName = "uploads";

var storageClient;
var blobServiceClient;

function Initialize(connectionString) {
  storageClient = TableClient.fromConnectionString(connectionString, tableName);
  blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
}

async function GetLatestVersion() {
  try {
    const listResults = storageClient.listEntities({
      queryOptions: {
        filter: odata`PartitionKey eq ${partitionKey}`,
      },
    });

    const iterator = listResults.byPage({ maxPageSize: 1 });
    for await (const page of iterator) {
      return page[0].version;
    }
  } catch (error) {
    console.log(error);
  }
}

async function GetSettingsByVersion(version, makefqdn) {
  try {
    if (version === undefined) version = await GetLatestVersion();
    if (makefqdn === undefined) makefqdn = true;

    const rowKey = getRowKeyFromVersion(version);
    const result = await storageClient.getEntity(partitionKey, rowKey);
    let item = {
      version: result.version,
      instancesPerNode: result.instancesPerNode,
      resolutionWidth: result.resolutionWidth,
      resolutionHeight: result.resolutionHeight,
      fps: result.fps,
      unrealApplicationDownloadUri: result.unrealApplicationDownloadUri,
      msImprovedWebserversDownloadUri: result.msImprovedWebserversDownloadUri,
      msPrereqsDownloadUri: result.msPrereqsDownloadUri,
      enableAutoScale: result.enableAutoScale,
      instanceCountBuffer: result.instanceCountBuffer,
      percentBuffer: result.percentBuffer,
      minMinutesBetweenScaledowns: result.minMinutesBetweenScaledowns,
      scaleDownByAmount: result.scaleDownByAmount,
      minInstanceCount: result.minInstanceCount,
      maxInstanceCount: result.maxInstanceCount,
      stunServerAddress: result.stunServerAddress,
      turnServerAddress: result.turnServerAddress,
      turnUsername: result.turnUsername,
      turnPassword: result.turnPassword,
    };

    if (makefqdn) {
      item.unrealApplicationDownloadUri = await extendWithSasToken(
        item.unrealApplicationDownloadUri
      );
      item.msImprovedWebserversDownloadUri = await extendWithSasToken(
        item.msImprovedWebserversDownloadUri
      );
      item.msPrereqsDownloadUri = await extendWithSasToken(
        item.msPrereqsDownloadUri
      );
    }

    return item;
  } catch (error) {
    console.log(error);
  }
}

async function WriteNewSettings(
  instancesPerNode,
  resolutionWidth,
  resolutionHeight,
  fps,
  unrealApplicationDownloadUri,
  enableAutoScale,
  instanceCountBuffer,
  percentBuffer,
  minMinutesBetweenScaledowns,
  scaleDownByAmount,
  minInstanceCount,
  maxInstanceCount,
  stunServerAddress,
  turnServerAddress,
  turnUsername,
  turnPassword
) {
  try {
    var currentSettings = await GetSettingsByVersion(undefined, false);
    var msImprovedWebserversDownloadUri =
      currentSettings.msImprovedWebserversDownloadUri;
    var msPrereqsDownloadUri = currentSettings.msPrereqsDownloadUri;

    var version = await GetLatestVersion();
    newVersion = version + 1;

    //Now, the code is not dependent on copy of the URI only
    //because in case of a custom image, the user can choose to change other properties. 
    if (unrealApplicationDownloadUri){
      await copyBlob(unrealApplicationDownloadUri, newVersion);
    }
    var entity = {
      partitionKey: partitionKey,
      rowKey: getRowKeyFromVersion(newVersion),
      version: newVersion,
      instancesPerNode: instancesPerNode,
      resolutionWidth: resolutionWidth,
      resolutionHeight: resolutionHeight,
      fps: fps,
      unrealApplicationDownloadUri: `unreal_${newVersion}.zip`,
      msImprovedWebserversDownloadUri: msImprovedWebserversDownloadUri,
      msPrereqsDownloadUri: msPrereqsDownloadUri,
      enableAutoScale: enableAutoScale,
      instanceCountBuffer: instanceCountBuffer,
      percentBuffer: percentBuffer,
      minMinutesBetweenScaledowns: minMinutesBetweenScaledowns,
      scaleDownByAmount: scaleDownByAmount,
      minInstanceCount: minInstanceCount,
      maxInstanceCount: maxInstanceCount,
      stunServerAddress: stunServerAddress,
      turnServerAddress: turnServerAddress,
      turnUsername: turnUsername,
      turnPassword: turnPassword
    };

    await storageClient.createEntity(entity);

    return newVersion;
  } catch (error) {
    console.log(error);
  }
}

async function GetSettingsList() {
  try {
    const listResults = storageClient.listEntities();
    let entities = [];
    const iterator = listResults.byPage({ maxPageSize: 10 });
    for await (const page of iterator) {
      entities = page;
      break;
    }

    return Promise.all(
      entities.map(async (entity) => {
        return {
          version: entity.version,
          instancesPerNode: entity.instancesPerNode,
          resolutionWidth: entity.resolutionWidth,
          resolutionHeight: entity.resolutionHeight,
          pixelstreamingApplicationName: entity.pixelstreamingApplicationName,
          fps: entity.fps,
          unrealApplicationDownloadUri: await extendWithSasToken(
            entity.unrealApplicationDownloadUri
          ),
          msImprovedWebserversDownloadUri: await extendWithSasToken(
            entity.msImprovedWebserversDownloadUri
          ),
          msPrereqsDownloadUri: await extendWithSasToken(
            entity.msPrereqsDownloadUri
          ),
          enableAutoScale: entity.enableAutoScale,
          instanceCountBuffer: entity.instanceCountBuffer,
          percentBuffer: entity.percentBuffer,
          minMinutesBetweenScaledowns: entity.minMinutesBetweenScaledowns,
          scaleDownByAmount: entity.scaleDownByAmount,
          minInstanceCount: entity.minInstanceCount,
          maxInstanceCount: entity.maxInstanceCount,
          stunServerAddress: entity.stunServerAddress,
          turnServerAddress: entity.turnServerAddress,
          turnUsername: entity.turnUsername,
          turnPassword: entity.turnPassword,
        };
      })
    );
  } catch (error) {
    console.log(error);
  }
}

async function GetUploadContainerContents() {
  const containerClient =
    blobServiceClient.getContainerClient(uploadContainerName);
  var blobs = [];
  for await (const blob of containerClient.listBlobsByHierarchy("/")) {
    var item = {
      name: blob.name,
      lastModified: blob.properties.lastModified,
      contentLength: blob.properties.contentLength,
    };

    blobs.push(item);
  }

  return blobs;
}

function getRowKeyFromVersion(version) {
  return (1000000 - version).toString();
}

async function extendWithSasToken(blobName) {
  var startDate = new Date();
  var expiryDate = new Date(startDate);
  //expiryDate.setMinutes(startDate.getMinutes() + 30);
  //startDate.setMinutes(startDate.getMinutes() - 5);

  expiryDate.setFullYear(startDate.getFullYear() + 1)
  startDate.setMinutes(startDate.getMinutes() - 30)

  var sharedAccessPolicy = {
    permissions: BlobSASPermissions.parse("r"),
    startsOn: startDate,
    expiresOn: expiryDate,
  };

  const container = blobServiceClient.getContainerClient(containerName);
  const blob = container.getBlobClient(blobName);
  var sasUrl = await blob.generateSasUrl(sharedAccessPolicy);

  return sasUrl;
}

async function copyBlob(sourceBlobName, newVersion) {
  const sourceContainer =
    blobServiceClient.getContainerClient(uploadContainerName);
  const desContainer = blobServiceClient.getContainerClient(containerName);

  //copy blob
  const sourceBlob = sourceContainer.getBlobClient(sourceBlobName);
  const desBlob = desContainer.getBlobClient(`unreal_${newVersion}.zip`);
  const response = await desBlob.beginCopyFromURL(sourceBlob.url);
  const result = await response.pollUntilDone();

  return result.copyStatus;
}

module.exports = {
  init: Initialize,
  GetLatestVersion,
  GetSettingsByVersion,
  WriteNewSettings,
  GetSettingsList,
  GetUploadContainerContents,
};

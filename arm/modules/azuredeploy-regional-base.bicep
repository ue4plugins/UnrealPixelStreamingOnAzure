targetScope = 'subscription'
param _artifactsLocation string

@secure()
param _artifactsLocationSasToken string
param location string
param randomString string
param globalRgName string
param globalRgLocation string
param basics_vmSizeSignalServer string
param basics_vmSizeMatchMaker string
param basics_vmStorageTypeMatchMaker string

@secure()
param basics_pixelStreamZip string
param basics_pixelStreamingAppName string
param basics_userModifications bool
param basics_adminName string

@secure()
param basics_adminPass string
param scale_gpuInstances int
param scale_instancesPerVM int
param scale_spotEnable bool
param scale_spotEvictionPolicy string
param scale_spotRestorePolicy bool
param scale_spotRestoreTimeout int = 60
param scale_spotEvictionType string
param scale_spotMaxPrice string = '-1'
param scale_enableAutoScale bool
param scale_percentBuffer int
param scale_instanceCountBuffer string
param scale_minMinutesBetweenScaledowns string
param scale_scaleDownByAmount string
param scale_minInstanceCount string
param scale_maxInstanceCount string
param stream_resolutionWidth string
param stream_resolutionHeight string
param stream_framesPerSecond string
param security_enablePixelStreamingCommands bool
param security_tmSubdomainName string
param security_enableHttps bool
param security_enableAuthOnSS bool
param security_dnsConfig object
param vnetAddressSpace array = [
  '10.102.0.0/16'
]
param subnetAddressSpace string = '10.102.0.0/22'
param network_matchmakerPublicPort string
param network_matchmakerInternalApiPort string
param network_matchmakerInternalPort string
param network_signallingserverPublicPortStart string
param network_pixelStreamingPort string
param network_turnServerAddress string
param network_stunServerAddress string
param network_turnUsername string

@secure()
param network_turnPassword string
param logAnalyticsWorkspaceName string

@secure()
param appInsightsInstrumentationKey string
param storageAccountName string
param keyVaultName string
param adminLocation string
param createCustomRoles bool
param customRole_mmOnGlobalRg string
param customRole_mmOnRegionalRg string
param customImageName string = ''

param allRegionVNets object
param allRegionSubnets object

var resourceGroupName = '${randomString}-${location}-unreal-rg'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  location: location
  name: resourceGroupName
  tags: {
    RandomString: randomString
  }
  properties: {
  }
}

resource Microsoft_Authorization_roleDefinitions_resourceGroup 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (createCustomRoles == true) {
  name: guid(resourceGroupName)
  properties: {
    roleName: 'Custom Role - MM MSI - ${randomString} - ${location} RG'
    description: 'All permissions the MM MSI needs on the Regional RG. This is to support the autoscaling of the VMSS'
    type: 'customRole'
    isCustom: true
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachineScaleSets/*'
        ]
      }
    ]
    assignableScopes: [
      '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroupName}'
    ]
  }
  dependsOn: [
    resourceGroup
  ]
}

module RegionalDeployment_randomString_location 'azuredeploy-regional.bicep' = {
  name: 'RegionalDeployment-${randomString}-${location}'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    location: location
    randomString: randomString
    globalRgName: globalRgName
    globalRgLocation: globalRgLocation
    basics_vmSizeSignalServer: basics_vmSizeSignalServer
    basics_vmSizeMatchMaker: basics_vmSizeMatchMaker
    basics_vmStorageTypeMatchMaker: basics_vmStorageTypeMatchMaker
    basics_pixelStreamZip: basics_pixelStreamZip
    basics_pixelStreamingAppName: basics_pixelStreamingAppName
    basics_userModifications: basics_userModifications
    basics_adminName: basics_adminName
    basics_adminPass: basics_adminPass
    scale_gpuInstances: scale_gpuInstances
    scale_instancesPerVM: scale_instancesPerVM
    scale_spotEnable: scale_spotEnable
    scale_spotEvictionPolicy: scale_spotEvictionPolicy
    scale_spotRestorePolicy: scale_spotRestorePolicy
    scale_spotRestoreTimeout: scale_spotRestoreTimeout
    scale_spotEvictionType: scale_spotEvictionType
    scale_spotMaxPrice: scale_spotMaxPrice
    scale_enableAutoScale: scale_enableAutoScale
    scale_percentBuffer: scale_percentBuffer
    scale_instanceCountBuffer: scale_instanceCountBuffer
    scale_minMinutesBetweenScaledowns: scale_minMinutesBetweenScaledowns
    scale_scaleDownByAmount: scale_scaleDownByAmount
    scale_minInstanceCount: scale_minInstanceCount
    scale_maxInstanceCount: scale_maxInstanceCount
    stream_resolutionWidth: stream_resolutionWidth
    stream_resolutionHeight: stream_resolutionHeight
    stream_framesPerSecond: stream_framesPerSecond
    security_tmSubdomainName: security_tmSubdomainName
    security_enableHttps: security_enableHttps
    security_dnsConfig: security_dnsConfig
    security_enableAuthOnSS: security_enableAuthOnSS
    network_matchmakerPublicPort: network_matchmakerPublicPort
    network_matchmakerInternalApiPort: network_matchmakerInternalApiPort
    network_matchmakerInternalPort: network_matchmakerInternalPort
    network_signallingserverPublicPortStart: network_signallingserverPublicPortStart
    network_pixelStreamingPort: network_pixelStreamingPort
    network_turnServerAddress: network_turnServerAddress
    network_stunServerAddress: network_stunServerAddress
    network_turnUsername: network_turnUsername
    network_turnPassword: network_turnPassword
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    storageAccountName: storageAccountName
    keyVaultName: keyVaultName
    adminLocation: adminLocation
    vnetAddressSpace: vnetAddressSpace
    subnetAddressSpace: subnetAddressSpace
    customRole_mmOnGlobalRg: customRole_mmOnGlobalRg
    customRole_mmOnRegionalRg: customRole_mmOnRegionalRg
    allRegionVNets: allRegionVNets
    allRegionSubnets: allRegionSubnets
    customImageName: customImageName
    security_enablePixelStreamingCommands: security_enablePixelStreamingCommands
  }
  dependsOn: [
    resourceGroup
  ]
}

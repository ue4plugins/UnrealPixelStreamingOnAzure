param _artifactsLocation string = deployment().properties.templateLink.uri

@secure()
param _artifactsLocationSasToken string = ''
param location string
param basics_vmSizeSignalServer string
param basics_vmSizeMatchMaker string
param basics_vmStorageTypeMatchMaker string = 'Standard_LRS'
param basics_customImage object = {}

@secure()
param basics_pixelStreamZip string = ''
param basics_pixelStreamingAppName string = ''
param basics_userModifications bool
param basics_adminName string

@secure()
param basics_adminPass string
param scale_regionsSelectedAsString string = ''
param scale_gpuInstances int = 2
param scale_instancesPerVM int = 1
param scale_spotEnable bool = false
param scale_spotEvictionPolicy string = 'Delete'
param scale_spotRestorePolicy bool = false
param scale_spotRestoreTimeout int = 60
param scale_spotEvictionType string = 'capacity'
param scale_spotMaxPrice string = '-1'
param scale_enableAutoScale bool = true
param scale_percentBuffer int = 25
param scale_instanceCountBuffer string = '1'
param scale_minMinutesBetweenScaledowns string = '1'
param scale_scaleDownByAmount string = '1'
param scale_minInstanceCount string = '1'
param scale_maxInstanceCount string = '1'
param stream_resolutionWidth string
param stream_resolutionHeight string
param stream_framesPerSecond string
param security_tmSubdomainName string = ''
param security_dnsConfig object = {}
param security_enableHttps bool = false

param security_enablePixelStreamingCommands bool = false

@secure()
param security_httpsPublicKey string = ''

@secure()
param security_httpsPrivateKey string = ''
param security_enableAuthOnSS bool = false
param network_matchmakerPublicPort string
param network_matchmakerInternalApiPort string
param network_matchmakerInternalPort string
param network_pixelStreamingPort string

@description('Has to be x.x.0.0/24, otherwise deployment will fail. Main VNET will have x.x.0.0/24, subsequent Regional VNETS will have 1.0/24, x.x.2.0/24, etc.')
param network_vnetMask string = '10.1.0.0/24'
param network_turnServerAddress string
param network_stunServerAddress string
param network_turnUsername string

param region1Vnet object = {}
param region2Vnet object = {}
param region3Vnet object = {}
param region4Vnet object = {}
param region1Subnet string = ''
param region2Subnet string = ''
param region3Subnet string = ''
param region4Subnet string = ''

@secure()
param network_turnPassword string
param dashboard_enable bool = true
param dashboard_aadClientId string = ''
param utcValue string = utcNow()

var randomString = 'a${substring(uniqueString(resourceGroup().id, deployment().name, utcValue), 1, 4)}'
var scale_regionsSelected = split(replace(replace(replace(replace(scale_regionsSelectedAsString, '"', ''), '[', ''), ']', ''), ' ', ''), ',')
var globalRgName = resourceGroup().name
var globalRgLocation = location
var adminLocation = (contains(scale_regionsSelected, globalRgLocation) ? globalRgLocation : scale_regionsSelected[0])
var customRole_mmOnGlobalRg_name = guid('CUSTOMROLE-GLOBAL-RG-${uniqueString(resourceGroup().id, deployment().name)}')
var createCustomRoles = ((subscription().tenantId != '72f988bf-86f1-41af-91ab-2d7cd011db47') ? true : false)
var ownerRoleDefId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
var network_vnetMask_start = substring(network_vnetMask, 0, (length(network_vnetMask) - 6))
var network_vnetMask_end = '.0/24'
var customImageName = empty(basics_customImage) ? '' : basics_customImage.id

var region1Info = length(scale_regionsSelected) >= 1 ? { '${scale_regionsSelected[0]}' : region1Vnet } : {}
var region2Info = length(scale_regionsSelected) >= 2 ? { '${scale_regionsSelected[1]}' : region2Vnet } : {}
var region3Info = length(scale_regionsSelected) >= 3 ? { '${scale_regionsSelected[2]}' : region3Vnet } : {}
var region4Info = length(scale_regionsSelected) >= 4 ? { '${scale_regionsSelected[3]}' : region4Vnet } : {}
var region1InfoSubnet = length(scale_regionsSelected) >= 1 ? { '${scale_regionsSelected[0]}' : replace(replace(replace(replace(region1Subnet, '"', ''), '\\', ''), '//', ''), ' ', '') } : {}
var region2InfoSubnet = length(scale_regionsSelected) >= 2 ? { '${scale_regionsSelected[1]}' : replace(replace(replace(replace(region2Subnet, '"', ''), '\\', ''), '//', ''), ' ', '') } : {}
var region3InfoSubnet = length(scale_regionsSelected) >= 3 ? { '${scale_regionsSelected[2]}' : replace(replace(replace(replace(region3Subnet, '"', ''), '\\', ''), '//', ''), ' ', '') } : {}
var region4InfoSubnet = length(scale_regionsSelected) >= 4 ? { '${scale_regionsSelected[3]}' : replace(replace(replace(replace(region4Subnet, '"', ''), '\\', ''), '//', ''), ' ', '') } : {}

var allRegionVNets = union(region1Info, region2Info, region3Info, region4Info)
var allRegionSubnets = union(region1InfoSubnet, region2InfoSubnet, region3InfoSubnet, region4InfoSubnet)

resource partnercenter 'Microsoft.Resources/deployments@2021-04-01' = {
  name: 'pid-a2a78148-1261-4be2-aa70-f5f877cc1fc9-partnercenter'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

module AddTagToGlobalRG_randomString 'modules/nested_AddTagToGlobalRG_randomString.bicep' = {
  name: 'AddTagToGlobalRG-${randomString}'
  scope: subscription(subscription().subscriptionId)
  params: {
    variables_globalRgName: globalRgName
    variables_randomString: randomString
    location: location
  }
}

resource customRole_mmOnGlobalRg 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (createCustomRoles == true) {
  name: customRole_mmOnGlobalRg_name
  properties: {
    roleName: 'Custom Role - MM MSI - ${randomString} - Global RG'
    description: 'All permissions the MM MSI needs on the Global RG. This is used during deployment time.'
    type: 'customRole'
    permissions: [
      {
        actions: (dashboard_enable ? [
          'microsoft.web/sites/*'
          'Microsoft.Insights/components/*'
        ] : [
          'Microsoft.Insights/components/*'
        ])
      }
    ]
    assignableScopes: [
      '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}'
    ]
  }
}

module GlobalDeployment 'modules/azuredeploy-global.bicep' = {
  name: 'GlobalDeployment'
  scope: resourceGroup(resourceGroup().name)
  params: {
    location: location
    randomString: randomString
    scale_regionsSelected: scale_regionsSelected
    security_enableHttps: security_enableHttps
    security_enableAuth: security_enableAuthOnSS
    security_dnsConfig: security_dnsConfig
    security_httpsPublicKey: security_httpsPublicKey
    security_httpsPrivateKey: security_httpsPrivateKey
    network_matchmakerPublicPort: network_matchmakerPublicPort
    dashboard_enable: dashboard_enable
    dashboard_aadClientId: dashboard_aadClientId
  }
}

module RegionalBaseDeployment_randomString_scale_regionsSelected 'modules/azuredeploy-regional-base.bicep' = [for (item, i) in scale_regionsSelected: {
  name: 'RegionalBaseDeployment-${randomString}-${item}'
  scope: subscription(subscription().subscriptionId)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    location: item
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
    network_signallingserverPublicPortStart: (security_enableHttps ? '443' : '80')
    network_pixelStreamingPort: network_pixelStreamingPort
    network_turnServerAddress: network_turnServerAddress
    network_stunServerAddress: network_stunServerAddress
    network_turnUsername: network_turnUsername
    network_turnPassword: network_turnPassword
    logAnalyticsWorkspaceName: GlobalDeployment.outputs.logAnalyticsWorkspaceName
    appInsightsInstrumentationKey: GlobalDeployment.outputs.appInsightsInstrumentationKey
    storageAccountName: GlobalDeployment.outputs.storageAccountName
    keyVaultName: GlobalDeployment.outputs.keyVaultName
    adminLocation: adminLocation
    vnetAddressSpace: [ ((adminLocation == item) ? network_vnetMask : '${network_vnetMask_start}${(i + 1)}${network_vnetMask_end}') ]
    subnetAddressSpace: ((adminLocation == item) ? network_vnetMask : '${network_vnetMask_start}${(i + 1)}${network_vnetMask_end}')
    createCustomRoles: createCustomRoles
    customRole_mmOnGlobalRg: ((createCustomRoles == true) ? customRole_mmOnGlobalRg_name : ownerRoleDefId)
    customRole_mmOnRegionalRg: ((createCustomRoles == true) ? guid('${randomString}-${item}-unreal-rg') : ownerRoleDefId)
    allRegionVNets: allRegionVNets
    allRegionSubnets: allRegionSubnets
    customImageName: customImageName
    security_enablePixelStreamingCommands: security_enablePixelStreamingCommands
  }
  dependsOn: [
    GlobalDeployment
  ]
}]

output arrayLength int = length(scale_regionsSelected)
output arrayScaleSelected array = scale_regionsSelected

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
param basics_pixelStreamZip string
param basics_pixelStreamingAppName string
param basics_userModifications bool
param basics_adminName string
param customImageName string = ''

@secure()
param basics_adminPass string
param scale_gpuInstances int
param scale_instancesPerVM int
param scale_spotEnable bool = false
param scale_spotEvictionPolicy string
param scale_spotRestorePolicy bool = false
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
param customRole_mmOnGlobalRg string
param customRole_mmOnRegionalRg string

param allRegionVNets object
param allRegionSubnets object

var virtualNetworkName = ((!empty(allRegionVNets[location])) ? allRegionVNets[location].name : '${randomString}-vnet-${location}')
var subnetName = ((!empty(allRegionSubnets[location])) ? allRegionSubnets[location] : '${randomString}-subnet-${location}')
var mmVmPipPrefixName = '${randomString}-mm-${location}'
var mmNsgName = '${randomString}-mm-nsg-${location}'
var ue4NsgName = '${randomString}-ue4-nsg-${location}'
var mmVmNamePrefixHost = '${randomString}-mm-vm'
var mmVmNamePrefixName = '${mmVmNamePrefixHost}-${location}'
var mmNicNamePrefixName = '${randomString}-mm-nic-${location}'
var vmssNameHost = '${randomString}vmss'
var vmssName = '${vmssNameHost}-${location}'
var isMainMatchmaker = (adminLocation == location)
//This offer is a Core VM Offer type
var mpDisk_publisher = 'marketplace-publisher-name'
var mpDisk_offer = 'marketplaceoffername'
var mpDisk_sku = 'marketplaceplanname'
var dnsConfigRg = ((!empty(security_dnsConfig)) ? split(security_dnsConfig.id, '/')[4] : 'wontbeused')
var concatted_tmSubdomainName = '${randomString}-${security_tmSubdomainName}'
var quote_appName = (empty(basics_pixelStreamingAppName) ? '' : ' -pixelstreamingApplicationName ${basics_pixelStreamingAppName}')
var externalRG = ((!empty(allRegionVNets[location])) ? last(take(split(allRegionVNets[location].id, '/'), 5)) : '')

var vnetAddressSpaceExisitingOrNew = vnetAddressSpace
var subnetAddressSpaceExistingOrNew = subnetAddressSpace

var defaultPlanInfo = {
  publisher: mpDisk_publisher
  offer: mpDisk_offer
  sku: mpDisk_sku
  version: 'latest' 
}
var customImageInfo = {
  id: customImageName
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-05-01' = if(empty(allRegionVNets[location])){
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressSpaceExisitingOrNew
    }
    enableDdosProtection: false
    enableVmProtection: false
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressSpaceExistingOrNew
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource mmNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: mmNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Open_IB_${network_matchmakerPublicPort}'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: network_matchmakerPublicPort
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'Open_IB_${network_matchmakerInternalPort}'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: network_matchmakerInternalPort
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1010
          direction: 'Inbound'
        }
      }
      {
        name: 'Open_IB_${network_matchmakerInternalApiPort}'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: network_matchmakerInternalApiPort
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1020
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource mmNsgName_Open_IB_443 'Microsoft.Network/networkSecurityGroups/securityRules@2020-05-01' = if (security_enableHttps == true) {
  parent: mmNsg
  name: 'Open_IB_443'
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 1030
    direction: 'Inbound'
  }
}

resource ue4Nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: ue4NsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Open_IB_HTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '${network_signallingserverPublicPortStart}-${(int(network_signallingserverPublicPortStart) + 3)}'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1020
          direction: 'Inbound'
        }
      }
      {
        name: 'Open_OB_${network_matchmakerInternalPort}'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: network_matchmakerInternalPort
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1010
          direction: 'Outbound'
        }
      }
      {
        name: 'Open_OB_${network_matchmakerInternalApiPort}'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: network_matchmakerInternalApiPort
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1020
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource mmVmPipPrefix 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: mmVmPipPrefixName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${location}-${randomString}-mm'
    }
  }
}

resource mmNicNamePrefix 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: mmNicNamePrefixName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${mmNicNamePrefixName}-config'
        properties: {
          publicIPAddress: {
            id: mmVmPipPrefix.id
          }
          subnet: {
            id: empty(externalRG) ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName) : resourceId(externalRG, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
          //privateIPAddress: mmPrivateStaticIpAddress  
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    networkSecurityGroup: {
      id: mmNsg.id
    }
    dnsSettings: {
      internalDnsNameLabel: 'mm-${randomString}-${location}-local'
    }
  }
  dependsOn: [

    virtualNetwork

  ]
}

resource mmVmNamePrefix 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: mmVmNamePrefixName
  location: location
  /* Uncomment for Azure VM Offer Type
  plan: {
    name: mpDisk_sku
    product: mpDisk_offer
    publisher: mpDisk_publisher
  }*/
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: basics_vmSizeMatchMaker
    }
    osProfile: {
      computerName: mmVmNamePrefixHost
      adminUsername: basics_adminName
      adminPassword: basics_adminPass
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
      allowExtensionOperations: true
    }
    storageProfile: {
      imageReference: empty(customImageName) ? defaultPlanInfo : customImageInfo
      osDisk: {
        name: '${mmVmNamePrefixName}-osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: mmNicNamePrefix.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    priority: 'Regular'
  }
}

resource Microsoft_Authorization_roleAssignments_mmVmNamePrefix 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mmVmNamePrefixName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', customRole_mmOnRegionalRg)
    principalId: reference(mmVmNamePrefix.id, '2020-06-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource vmss 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vmssName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', customRole_mmOnRegionalRg)
    principalId: reference(Microsoft_Compute_virtualMachineScaleSets_vmss.id, '2020-06-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

module RolesAndAccessPoliciesOnGlobalRg_for_MM_location './nested_RolesAndAccessPoliciesOnGlobalRg_for_MM_location.bicep' = {
  name: 'RolesAndAccessPoliciesOnGlobalRg-for-MM-${location}'
  scope: resourceGroup(globalRgName)
  params: {
    resourceId_Microsoft_Compute_virtualMachines_variables_mmVmNamePrefix: reference(mmVmNamePrefix.id, '2020-06-01', 'full')
    variables_mmVmNamePrefix: mmVmNamePrefixName
    globalRgName: globalRgName
    customRole_mmOnGlobalRg: customRole_mmOnGlobalRg
    keyVaultName: keyVaultName
  }
}

module RolesAndAccessPoliciesOnGlobalRg_for_SS_DNS_randomString_location './nested_RolesAndAccessPoliciesOnGlobalRg_for_SS_DNS_randomString_location.bicep' = if (!empty(security_dnsConfig)) {
  name: 'RolesAndAccessPoliciesOnGlobalRg-for-SS-DNS-${randomString}${location}'
  scope: resourceGroup(dnsConfigRg)
  params: {
    resourceId_Microsoft_Compute_virtualMachineScaleSets_variables_vmssName: reference(Microsoft_Compute_virtualMachineScaleSets_vmss.id, '2020-06-01', 'full')
    variables_vmssName: vmssName
    security_dnsConfig: security_dnsConfig
    randomString: randomString
  }
}

module RolesAndAccessPoliciesOnGlobalRg_for_MM_DNS_randomString_location './nested_RolesAndAccessPoliciesOnGlobalRg_for_MM_DNS_randomString_location.bicep' = if (!empty(security_dnsConfig)) {
  name: 'RolesAndAccessPoliciesOnGlobalRg-for-MM-DNS-${randomString}${location}'
  scope: resourceGroup(dnsConfigRg)
  params: {
    resourceId_Microsoft_Compute_virtualMachines_variables_mmVmNamePrefix: reference(mmVmNamePrefix.id, '2020-06-01', 'full')
    variables_mmVmNamePrefix: mmVmNamePrefixName
    security_dnsConfig: security_dnsConfig
    randomString: randomString
  }
}

module RolesAndAccessPoliciesOnGlobalRg_for_SS_location './nested_RolesAndAccessPoliciesOnGlobalRg_for_SS_location.bicep' = {
  name: 'RolesAndAccessPoliciesOnGlobalRg-for-SS-${location}'
  scope: resourceGroup(globalRgName)
  params: {
    resourceId_Microsoft_Compute_virtualMachineScaleSets_variables_vmssName: reference(Microsoft_Compute_virtualMachineScaleSets_vmss.id, '2020-06-01', 'full')
    keyVaultName: keyVaultName
  }
  dependsOn: [
    RolesAndAccessPoliciesOnGlobalRg_for_MM_location
  ]
}

resource mmVmNamePrefix_MMAExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: mmVmNamePrefix
  name: 'MMAExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentWindows'
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
}

resource mmVmNamePrefix_MonitoringAgentWindows 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: mmVmNamePrefix
  name: 'MonitoringAgentWindows'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: reference(resourceId(globalRgName, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName), '2020-10-01').customerId
    }
    protectedSettings: {
      workspaceKey: listKeys(resourceId(globalRgName, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName), '2020-10-01').primarySharedKey
    }
  }
}

resource mmVmNamePrefix_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  parent: mmVmNamePrefix
  name: 'CustomScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        uri(_artifactsLocation, 'mp_mm_setup.ps1${_artifactsLocationSasToken}')
        uri(_artifactsLocation, 'msImprovedWebservers.zip${_artifactsLocationSasToken}')
        uri(_artifactsLocation, 'msPrereqs.zip${_artifactsLocationSasToken}')
        uri(_artifactsLocation, 'msDashboard.zip${_artifactsLocationSasToken}')
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -NoProfile -NonInteractive -command "./mp_mm_setup.ps1 -subscriptionId ${subscription().subscriptionId} -globalRgName ${globalRgName} -globalRgLocation ${globalRgLocation} -resourceGroupName ${resourceGroup().name} -vmssName ${vmssName} -appInsightsInstrumentationKey ${appInsightsInstrumentationKey} -unrealApplicationDownloadUri \'${basics_pixelStreamZip}\' -enableAutoScale ${scale_enableAutoScale} -percentBuffer ${scale_percentBuffer} -instanceCountBuffer ${scale_instanceCountBuffer} -minMinutesBetweenScaledowns ${scale_minMinutesBetweenScaledowns} -scaleDownByAmount ${scale_scaleDownByAmount} -minInstanceCount ${scale_minInstanceCount} -maxInstanceCount ${scale_maxInstanceCount} -matchmakerPublicPort ${network_matchmakerPublicPort} -matchmakerInternalApiAddress ${mmNicNamePrefix.properties.ipConfigurations[0].properties.privateIPAddress} -matchmakerInternalApiPort ${network_matchmakerInternalApiPort} -matchmakerInternalPort ${network_matchmakerInternalPort} -isMainMatchmaker ${isMainMatchmaker} -enableAuth ${security_enableAuthOnSS} -instancesPerNode ${scale_instancesPerVM} -resolutionWidth ${stream_resolutionWidth} -resolutionHeight ${stream_resolutionHeight}${quote_appName} -fps ${stream_framesPerSecond} -storageConnectionString \'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(resourceId(globalRgName, 'Microsoft.Storage/storageAccounts', storageAccountName), '2021-06-01').keys[0].value};EndpointSuffix=${replace(split(reference(resourceId(globalRgName, 'Microsoft.Storage/storageAccounts', storageAccountName), '2021-06-01').primaryEndpoints.blob, 'blob.')[1], '/', '')}\' -userModifications ${basics_userModifications} -enableHttps ${security_enableHttps} -customDomainName \'${((!empty(security_dnsConfig)) ? security_dnsConfig.name : '')}\' -dnsConfigRg \'${dnsConfigRg}\' -tmSubdomainName \'${concatted_tmSubdomainName}\' -turnServerAddress \'${network_turnServerAddress}\' -stunServerAddress \'${network_stunServerAddress}\' -turnUsername \'${network_turnUsername}\' -turnPassword \'${network_turnPassword}\' -storageAccountKey \'${listKeys(resourceId(globalRgName, 'Microsoft.Storage/storageAccounts', storageAccountName), '2021-06-01').keys[0].value}\' -storageAccountName \'${storageAccountName}\' -customImageName \'${customImageName}\';"'
    }
  }
  dependsOn: [
    RolesAndAccessPoliciesOnGlobalRg_for_MM_location
    RolesAndAccessPoliciesOnGlobalRg_for_MM_DNS_randomString_location
  ]
}

resource Microsoft_Compute_virtualMachineScaleSets_vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-07-01' = {
  name: vmssName
  location: location
  sku: {
    name: basics_vmSizeSignalServer
    tier: 'Standard'
    capacity: scale_gpuInstances
  }
  /* Uncomment for Azure VM Offer Type
  plan: {
    publisher: mpDisk_publisher
    product: mpDisk_offer
    name: mpDisk_sku
  }*/
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    singlePlacementGroup: scale_spotEnable ? false : true
    spotRestorePolicy: scale_spotEnable ? {
      enabled: scale_spotRestorePolicy
      restoreTimeout: 'PT${scale_spotRestoreTimeout}M'
    } : null
    upgradePolicy: { mode: 'Automatic' }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: vmssNameHost
        adminUsername: basics_adminName
        adminPassword: basics_adminPass
        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
        }
      }
      storageProfile: {
        imageReference: empty(customImageName) ? defaultPlanInfo : customImageInfo
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: basics_vmStorageTypeMatchMaker
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${vmssName}-nic-${location}'
            properties: {
              primary: true
              networkSecurityGroup: {
                id: ue4Nsg.id
              }
              ipConfigurations: [
                {
                  name: 'external'
                  properties: {
                    publicIPAddressConfiguration: {
                      name: '${vmssName}-public-ip'
                      properties: {
                        idleTimeoutInMinutes: 4
                        dnsSettings: {
                          domainNameLabel: vmssName
                        }
                        publicIPAddressVersion: 'IPv4'
                      }
                    }
                    subnet: {
                      id: empty(externalRG) ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName) : resourceId(externalRG, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
                    }
                    privateIPAddressVersion: 'IPv4'
                  }
                }
              ]
            }
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: false
        }
      }
      extensionProfile: {
        extensions: [
          {
            name: 'MMAExtension'
            properties: {
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
              type: 'DependencyAgentWindows'
              typeHandlerVersion: '9.5'
            }
          }
          {
            name: 'MonitoringAgentWindows'
            properties: {
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.EnterpriseCloud.Monitoring'
              type: 'MicrosoftMonitoringAgent'
              typeHandlerVersion: '1.0'
              settings: {
                workspaceId: reference(resourceId(globalRgName, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName), '2020-10-01').customerId
              }
              protectedSettings: {
                workspaceKey: listKeys(resourceId(globalRgName, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName), '2020-10-01').primarySharedKey
              }
            }
          }
        ]
      }
      priority: scale_spotEnable ? 'Spot' : 'Regular'
      evictionPolicy: scale_spotEnable ? scale_spotEvictionPolicy : null
      billingProfile: scale_spotEnable ? {
        maxPrice: scale_spotEvictionType == 'price' ? scale_spotMaxPrice : -1
      } : {}
    }
    overprovision: true
    doNotRunExtensionsOnOverprovisionedVMs: false
  }
  dependsOn: [
    virtualNetwork
    mmVmPipPrefix
  ]
}

resource vmssName_ue4_extension 'Microsoft.Compute/virtualMachineScaleSets/extensions@2021-07-01' = {
  parent: Microsoft_Compute_virtualMachineScaleSets_vmss
  name: 'ue4-extension'
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    protectedSettings: {
      fileUris: [
        uri(_artifactsLocation, 'mp_ss_setup.ps1${_artifactsLocationSasToken}')
        uri(_artifactsLocation, 'msImprovedWebservers.zip${_artifactsLocationSasToken}')
        uri(_artifactsLocation, 'msPrereqs.zip${_artifactsLocationSasToken}')
      ]
     commandToExecute: 'powershell -ExecutionPolicy Unrestricted -NoProfile -NonInteractive -command "./mp_ss_setup.ps1 -subscriptionId ${subscription().subscriptionId} -resourceGroupName ${resourceGroup().name} -vmssName ${vmssName} -appInsightsInstrumentationKey ${appInsightsInstrumentationKey} -mm_lb_fqdn ${mmNicNamePrefix.properties.dnsSettings.internalDnsNameLabel} -instancesPerNode ${scale_instancesPerVM} -streamingPort ${network_pixelStreamingPort} -resolutionWidth ${stream_resolutionWidth} -resolutionHeight ${stream_resolutionHeight}${quote_appName} -fps ${stream_framesPerSecond} -unrealApplicationDownloadUri \'${basics_pixelStreamZip}\' -signallingserverPublicPortStart ${network_signallingserverPublicPortStart} -matchmakerInternalPort ${network_matchmakerInternalPort} -matchmakerInternalApiAddress ${mmNicNamePrefix.properties.ipConfigurations[0].properties.privateIPAddress} -matchmakerInternalApiPort ${network_matchmakerInternalApiPort} -userModifications ${basics_userModifications} -enableHttps ${security_enableHttps} -enableAuthentication ${security_enableAuthOnSS} -customDomainName \'${((!empty(security_dnsConfig)) ? security_dnsConfig.name : '')}\' -dnsConfigRg \'${dnsConfigRg}\' -turnServerAddress \'${network_turnServerAddress}\' -stunServerAddress \'${network_stunServerAddress}\' -turnUsername \'${network_turnUsername}\' -turnPassword \'${network_turnPassword}\' -customImage \'${customImageName}\' -allowPixelStreamingCommands \'${security_enablePixelStreamingCommands}\';"'
    }
  }
  dependsOn: [
    mmVmNamePrefix
    RolesAndAccessPoliciesOnGlobalRg_for_SS_DNS_randomString_location
  ]
}

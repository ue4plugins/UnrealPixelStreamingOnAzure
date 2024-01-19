param location string
param randomString string
param scale_regionsSelected array
param security_enableHttps bool
param security_enableAuth bool
param security_dnsConfig object

@secure()
param security_httpsPublicKey string

@secure()
param security_httpsPrivateKey string
param network_matchmakerPublicPort string
param dashboard_enable bool
param dashboard_aadClientId string

var keyVaultName = 'akv-${randomString}'
var trafficManagerProfileName = '${randomString}-trafficmgr-mm'
var logAnalyticsWorkspaceName = '${randomString}-loganalytics'
var appInsightsName = '${randomString}-appinsights'
var appInsightsActionGroupName = 'Application Insights Smart Detection'
var webAppName = '${randomString}-dashboard'
var hostingPlanName = '${randomString}-dashboard-hpn'
var storageAccountName = '${randomString}admin'
var storageAccountType = 'Standard_LRS'

resource logAnalyticsWorkspace 'microsoft.operationalinsights/workspaces@2020-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'pergb2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource logAnalyticsWorkspaceName_logAnalyticsWorkspaceName_armlog_newline 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: logAnalyticsWorkspace
  name: '${logAnalyticsWorkspaceName}armlog_newline'
  kind: 'CustomLog'
  properties: {
    customLogName: 'armlog_newline'
    description: 'This sections deals with parsing the logs from MM and VMSS instances'
    inputs: [
      {
        location: {
          fileSystemLocations: {
            windowsFileTypeLogPaths: [
              'c:\\gaming\\logs\\*.txt'
            ]
          }
        }
        recordDelimiter: {
          regexDelimiter: {
            pattern: '\\n'
            matchIndex: 0
            numberdGroup: null
          }
        }
      }
    ]
    extractions: [
      {
        extractionName: 'TimeGenerated'
        extractionType: 'DateTime'
        extractionProperties: {
          dateTimeExtraction: {
            regex: null
            joinStringRegex: null
          }
        }
      }
    ]
  }
}

resource appInsightsActionGroup 'microsoft.insights/actionGroups@2021-09-01' = {
  name: appInsightsActionGroupName
  location: 'Global'
  properties: {
    groupShortName: 'SmartDetect'
    enabled: true
  }
}

resource appInsights 'microsoft.insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'premium'
    }
    accessPolicies: []
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
  }
}

resource kvDiagnotsicsLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-kv-logs'
  scope: keyVault
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

resource keyVaultName_https_privatekey 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = if (security_enableHttps == true) {
  parent: keyVault
  name: 'https-privatekey'
  properties: {
    value: security_httpsPrivateKey
  }
}

resource keyVaultName_https_publickey 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = if (security_enableHttps == true) {
  parent: keyVault
  name: 'https-publickey'
  properties: {
    value: security_httpsPublicKey
  }
}

resource trafficManagerProfile 'Microsoft.Network/trafficManagerProfiles@2018-08-01' = {
  name: trafficManagerProfileName
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: trafficManagerProfileName
      ttl: 100
    }
    monitorConfig: {
      profileMonitorStatus: 'Online'
      protocol: 'HTTP'
      port: network_matchmakerPublicPort
      path: '/ping'
      intervalInSeconds: 30
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
    }
  }
}

resource trafficManagerProfileName_region_scale_regionsSelected 'Microsoft.Network/trafficManagerProfiles/ExternalEndpoints@2018-08-01' = [for item in scale_regionsSelected: {
  name: '${trafficManagerProfileName}/region-${item}'
  properties: {
    target: '${item}-${randomString}-mm.${item}.cloudapp.azure.com'
    endpointStatus: 'Enabled'
    endpointLocation: item
  }
  dependsOn: [
    trafficManagerProfile
  ]
}]

resource trafficManagerProfileName_region_scale_regionsSelected_customdomain 'Microsoft.Network/trafficManagerProfiles/ExternalEndpoints@2018-08-01' = [for item in scale_regionsSelected: if (!empty(security_dnsConfig)) {
  name: '${trafficManagerProfileName}/region-${item}-customdomain'
  properties: {
    target: '${randomString}-mm-${item}.${security_dnsConfig.name}'
    endpointStatus: 'Enabled'
    endpointLocation: item
  }
  dependsOn: [
    trafficManagerProfile
  ]
}]

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
  }
}

resource webApp 'Microsoft.Web/sites@2020-09-01' = if (dashboard_enable == true) {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    name: webAppName
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: true
        }
        {
          name: 'STORAGECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccount.id, '2021-06-01').keys[0].value};EndpointSuffix=${split(reference(storageAccount.id, '2021-06-01').primaryEndpoints.blob, 'blob.')[1]}'
        }
        {
          name: 'KEYVAULTNAME'
          value: keyVaultName
        }
        {
          name: 'ENABLEAUTHENTICATION'
          value: security_enableAuth
        }
      ]
      phpVersion: 'OFF'
      nodeVersion: '~14'
      alwaysOn: false
    }
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: false
  }
}

resource webAppName_authsettings 'Microsoft.Web/sites/config@2020-09-01' = if (dashboard_enable == true) {
  parent: webApp
  name: 'authsettings'
  properties: {
    enabled: true
    unauthenticatedClientAction: 'RedirectToLoginPage'
    tokenStoreEnabled: false
    defaultProvider: 'AzureActiveDirectory'
    clientId: dashboard_aadClientId
    issuer: 'https://sts.windows.net/${subscription().tenantId}/'
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2020-09-01' = if (dashboard_enable == true) {
  name: hostingPlanName
  location: location
  sku: {
    tier: 'Standard'
    name: 'S1'
  }
  properties: {
    name: hostingPlanName
    workerSize: '0'
    workerSizeId: '0'
    numberOfWorkers: '1'
  }
}

resource keyVaultName_add 'Microsoft.KeyVault/vaults/accessPolicies@2021-10-01' = if (dashboard_enable == true) {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: (dashboard_enable ? reference(webApp.id, '2020-09-01', 'Full').identity.principalId : '')
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

output logAnalyticsWorkspaceName string = logAnalyticsWorkspaceName
output appInsightsInstrumentationKey string = reference(appInsights.id, '2020-02-02').InstrumentationKey
output storageAccountName string = storageAccountName
output keyVaultName string = keyVaultName

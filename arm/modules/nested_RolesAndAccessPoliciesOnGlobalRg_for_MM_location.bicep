param resourceId_Microsoft_Compute_virtualMachines_variables_mmVmNamePrefix object
param variables_mmVmNamePrefix string
param globalRgName string
param customRole_mmOnGlobalRg string
param keyVaultName string

resource variables_mmVmNamePrefix_globalRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${variables_mmVmNamePrefix}${globalRgName}')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', customRole_mmOnGlobalRg)
    principalId: resourceId_Microsoft_Compute_virtualMachines_variables_mmVmNamePrefix.identity.principalId
    principalType: 'ServicePrincipal'    
  }
}

resource keyVaultName_add 'Microsoft.KeyVault/vaults/accessPolicies@2021-06-01-preview' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: resourceId_Microsoft_Compute_virtualMachines_variables_mmVmNamePrefix.identity.principalId
        permissions: {
          secrets: [
            'list'
            'get'
            'set'
          ]
        }
      }
    ]
  }
}

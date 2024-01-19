param resourceId_Microsoft_Compute_virtualMachineScaleSets_variables_vmssName object
param keyVaultName string

resource keyVaultName_add 'Microsoft.KeyVault/vaults/accessPolicies@2021-06-01-preview' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: resourceId_Microsoft_Compute_virtualMachineScaleSets_variables_vmssName.identity.principalId
        permissions: {
          secrets: [
            'list'
            'get'
          ]
        }
      }
    ]
  }
}
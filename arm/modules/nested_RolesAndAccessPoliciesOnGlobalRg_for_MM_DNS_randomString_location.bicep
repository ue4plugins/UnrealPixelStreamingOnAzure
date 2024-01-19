param resourceId_Microsoft_Compute_virtualMachines_variables_mmVmNamePrefix object
param variables_mmVmNamePrefix string
param security_dnsConfig object
param randomString string

resource security_dnsConfig_name_Microsoft_Authorization_variables_mmVmNamePrefix_randomString_security_dnsConfig_id 'Microsoft.Network/dnszones/providers/roleAssignments@2021-04-01-preview' = {
  name: '${security_dnsConfig.name}/Microsoft.Authorization/${guid('${variables_mmVmNamePrefix}${randomString}${security_dnsConfig.id}')}'
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalId: resourceId_Microsoft_Compute_virtualMachines_variables_mmVmNamePrefix.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

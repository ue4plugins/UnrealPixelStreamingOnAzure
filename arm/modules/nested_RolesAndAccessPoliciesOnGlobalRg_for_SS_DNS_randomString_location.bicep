param resourceId_Microsoft_Compute_virtualMachineScaleSets_variables_vmssName object
param variables_vmssName string
param security_dnsConfig object
param randomString string

resource security_dnsConfig_name_Microsoft_Authorization_variables_vmssName_randomString_security_dnsConfig_id 'Microsoft.Network/dnszones/providers/roleAssignments@2021-04-01-preview' = {
  name: '${security_dnsConfig.name}/Microsoft.Authorization/${guid('${variables_vmssName}${randomString}${security_dnsConfig.id}')}'
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalId: resourceId_Microsoft_Compute_virtualMachineScaleSets_variables_vmssName.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

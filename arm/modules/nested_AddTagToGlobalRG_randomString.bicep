targetScope = 'subscription'
param variables_globalRgName string
param variables_randomString string
param location string

resource variables_globalRg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  location: location
  name: variables_globalRgName
  tags: {
    RandomString: variables_randomString
  }
}

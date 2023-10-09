param location string = 'japaneast'
param nsgName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: []
  }
}

output nsgId string = nsg.id

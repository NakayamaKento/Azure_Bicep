param location string = 'japaneast'
param Name string

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: Name
  location: location
  properties: {
    securityRules: []
  }
}

output nsgId string = nsg.id

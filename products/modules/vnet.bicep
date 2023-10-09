param location string = 'japaneast'
param Name string
param vnetAddress string = '10.0.0.0'

var vnetName = '${Name}-vnet'
var subnetName = '${Name}-subnet'
var vnetAddressPrefix = '${vnetAddress}/16'
var subnetAddressPrefix = '${vnetAddress}/24'

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: subnetAddressPrefix
  }
}

output vnetId string = vnet.id

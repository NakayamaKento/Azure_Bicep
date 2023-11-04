param location string = 'japaneast'
param Name string
param vnetAddress string = '10.0.0.0'
param bastion bool = false
param firewall bool = false
param gateway bool = false

var vnetName = '${Name}-vnet'
var vnetAddressPrefix = cidrSubnet(vnetAddress, 16, 0)
var subnets = [
  {
    name: 'default'
    addressPrefix: cidrSubnet(vnetAddress, 24, 0)
    exist: true
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: cidrSubnet(vnetAddress, 24, 1)
    exist: bastion
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: cidrSubnet(vnetAddress, 24, 2)
    exist: firewall
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: cidrSubnet(vnetAddress, 24, 3)
    exist: gateway
  }
]

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

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = [for subnetinfo in subnets: if (subnetinfo.exist) {
    name: subnetinfo.name
    parent: vnet
    properties: {
      addressPrefix: subnetinfo.addressPrefix
    }
  }
]

output vnetId string = vnet.id

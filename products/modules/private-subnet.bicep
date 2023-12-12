param location string
param Name string
param vnetAddress string
param bastion bool = false
param firewall bool = false
param gateway bool = false
param nsgid string
param privatesubnetpolicy bool = false

var vnetName = '${Name}-vnet'
var vnetAddressPrefix = cidrSubnet(vnetAddress, 16, 0)
var subnets = [
  {
    name: 'default'
    addressPrefix: cidrSubnet(vnetAddress, 24, 0)
    exist: true
    nsg: true
    privatesubnet: privatesubnetpolicy
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: cidrSubnet(vnetAddress, 24, 1)
    exist: bastion
    nsg: false
    privatesubnet: false
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: cidrSubnet(vnetAddress, 24, 2)
    exist: firewall
    nsg: false
    privatesubnet: false
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: cidrSubnet(vnetAddress, 24, 3)
    exist: gateway
    nsg: false
    privatesubnet: false
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
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
      networkSecurityGroup: subnetinfo.nsg ? { id: nsgid } : null
      defaultOutboundAccess: subnetinfo.privatesubnet
    }
  }
]

output vnetId string = vnet.id
output subnets array = subnets

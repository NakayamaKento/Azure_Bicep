/*
1つの Vnet の中に1つのサブネットを作成します
サブネットには RDP を許可する NSG を関連付けます
*/

param location string = resourceGroup().location
param vnetaddress string = '10.0.0.0/16'
param name string = 'hoge'

param allow_rdp bool = false
param allow_ssh bool = false

var nsgName = 'nsg-${name}'
var vnetName = 'vnet-${name}'


// module を使用した NSG の作成
module nsg 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: nsgName
  params: {
    location: location
    name: nsgName
    securityRules: [
      (allow_rdp) ? {
        name: 'allowRDP'
        properties: {
          access: 'Allow'
          description: 'Tests specific IPs and ports'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          direction: 'Inbound'
          priority: 100
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
    : {
      name: 'denyRDP'
        properties: {
          access: 'Deny'
          description: 'Tests specific IPs and ports'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          direction: 'Inbound'
          priority: 100
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
    }
  (allow_ssh) ? {
    name: 'allowSSH'
    properties: {
      access: 'Allow'
      description: 'Tests specific IPs and ports'
      destinationAddressPrefix: '*'
      destinationPortRange: '22'
      direction: 'Inbound'
      priority: 101
      protocol: '*'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
    }
      }
    :  {
      name: 'denySSH'
        properties: {
          access: 'Deny'
          description: 'Tests specific IPs and ports'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          direction: 'Inbound'
          priority: 101
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
    }
    ]
  }
}


// module を使用した Vnet の作成
module vnet 'br/public:avm/res/network/virtual-network:0.3.0' = {
  name: vnetName
  params: {
    name: vnetName
    addressPrefixes: [
      vnetaddress
    ]
    subnets:[
      {
        name: 'default'
        addressPrefix: cidrSubnet(vnetaddress, 24, 0)
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: cidrSubnet(vnetaddress, 24, 1)
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: cidrSubnet(vnetaddress, 24, 2)
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: cidrSubnet(vnetaddress, 24, 3)
      }
    ]
  }
}

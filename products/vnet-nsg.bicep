/*
1つの Vnet の中に1つのサブネットを作成します
サブネットには RDP を許可する NSG を関連付けます
*/

param location string = 'japaneast'
param vnetName string = 'myVnet'
param addressPrefix string = '10.0.0.0/16'
param subnetName string = 'mySubnet'
param subnetPrefix string = '10.0.0.0/24'
param nsgName string = 'myNsg'


param allow_rdp bool = true


module nsg './modules/nsg.bicep' = {
  name: nsgName
  params: {
    location: location
    nsgName: nsgName
  }
}


module allow_rdp_rule 'modules/nsg-rules.bicep' = if (allow_rdp) {
  name: 'allow_rdp_rule'
  params: {
    nsgName: nsgName
    ruleName: 'allowRDP'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'TCP'
    sourcePortRange: '*'
    destinationPortRange: '3389'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '*'
  }
  dependsOn: [
    nsg
  ]
}


resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.outputs.nsgId
          }
        }
      }
    ]
  }
}

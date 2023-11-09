/*
1つの Vnet の中に1つのサブネットを作成します
サブネットには RDP を許可する NSG を関連付けます
*/

param location string = 'japaneast'
param vnetName string = 'my01'
param vnetaddress string = '10.0.0.0/16'
param nsgName string = 'my01'

param allow_rdp bool = false
param allow_ssh bool = false

param bastion bool = false
param firewall bool = false
param gateway bool = false

// module を使用した NSG の作成
module nsg './modules/nsg.bicep' = {
  name: nsgName
  params: {
    location: location
    Name: nsgName
  }
}

// module を使用した NSG ルールの作成
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

// module を使用した NSG ルールの作成
module allow_ssh_rule 'modules/nsg-rules.bicep' = if (allow_ssh) {
  name: 'allow_ssh_rule'
  params: {
    nsgName: nsgName
    ruleName: 'allowSSH'
    priority: 101
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'TCP'
    sourcePortRange: '*'
    destinationPortRange: '22'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '*'
  }
  dependsOn: [
    nsg
  ]
}

// module を使用した Vnet の作成
module vnet './modules/vnet.bicep' = {
  name: vnetName
  params: {
    Name: vnetName
    vnetAddress: vnetaddress
    location: location
    nsgid: nsg.outputs.nsgId
    bastion: bastion
    firewall: firewall
    gateway: gateway
  }
}

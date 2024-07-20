@description('すべてのリソースに共通する接頭語です')
param prefix string

@description('リソースの場所')
param location string = resourceGroup().location

@description('Azure Arc 対応サーバーのユーザー名')
param vmUserName string = 'AzureAdmin'

@description('VM の認証タイプ')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('Azure Arc 対応サーバーのパスワードまたは SSH キー')
@secure()
param adminPasswordOrKey string

@description('VM のサイズ')
param vmSize string = 'Standard_D4s_v3'

@allowed([
  'no'
  'yes'
])
@description('Bastion をデプロイするかどうか')
param deployBastion string = 'no'

@description('Azure Arc の接続にデバイスコードを利用するかどうか。false の場合、サービスプリンシパルを利用')
param useDeviceCode bool = true

@description('サービス プリンシパルの ID。デバイスコードを利用する場合はスルー')
param appId string

@description('サービス プリンシパルの シークレット。デバイスコードを利用する場合は適当に埋める')
@secure()
param appSecret string

@description('Vnet のアドレス空間')
param vnetAdressPrefix string = '10.0.0.0/16'

var vmName = '${prefix}-arcvm'
var tenantId = subscription().tenantId
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var nicIpConfigurations = {
  // Bastion を使わない場合、VM に Public IP を割り当てる
  no: {
    name: '${prefix}-ipconfig'
    subnetResourceId: vnet.outputs.subnetResourceIds[0]
    pipConfiguration: {
      name: '${prefix}-pip'
    }
  }
  yes: {
    name: '${prefix}-ipconfig'
    subnetResourceId: vnet.outputs.subnetResourceIds[0]
  }
}

// NSG
module nsg 'br/public:avm/res/network/network-security-group:0.3.1' = {
  name: '${prefix}-nsg'
  params: {
    name: '${prefix}-nsg'
    // Non-required parameters
    location: location
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '22'
          ]
          direction: 'Inbound'
          priority: 200
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
    ]
  }
}

// Vnet
module vnet 'br/public:avm/res/network/virtual-network:0.1.8' = {
  name: '${prefix}-vnet'
  params: {
    addressPrefixes: [
      vnetAdressPrefix
    ]
    name: '${prefix}-vnet'
    location: location
    subnets: [
      {
        name: 'default'
        addressPrefix: cidrSubnet(vnetAdressPrefix, 24, 0)
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: cidrSubnet(vnetAdressPrefix, 24, 1)
      }
    ]
  }
}

// VM
module vm 'br/public:avm/res/compute/virtual-machine:0.5.3' = {
  name: vmName
  params: {
    adminUsername: vmUserName
    adminPassword: adminPasswordOrKey
    disablePasswordAuthentication: (authenticationType == 'sshPublicKey') ? true : false
    publicKeys: (authenticationType == 'sshPublicKey')
      ? [
          {
            path: '/home/${vmUserName}/.ssh/authorized_keys'
            keyData: adminPasswordOrKey
          }
        ]
      : null
    imageReference: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts'
      version: 'latest'
    }
    name: vmName
    nicConfigurations: [
      {
        nicSuffix: '-nic'
        ipConfigurations: [
          nicIpConfigurations[deployBastion]
        ]
      }
    ]
    osDisk: {
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    osType: 'Linux'
    vmSize: vmSize
    zone: 0
    // Arc 用の拡張機能
    extensionCustomScriptConfig: {
      enabled: true
      fileData: [
        {
          uri: ((useDeviceCode)
            ? 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/main/products/ArcEnabledLinuxServer/scripts/install_arc_agent_deviceCode.sh'
            : 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/main/products/ArcEnabledLinuxServer/scripts/install_arc_agent.sh')
        }
      ]
    }
    extensionCustomScriptProtectedSetting: {
      commandToExecute: ((useDeviceCode)
        ? './install_arc_agent_deviceCode.sh ${vmUserName} ${subscriptionId} ${tenantId} ${resourceGroupName} ${location} ${vmName}'
        : './install_arc_agent.sh ${vmUserName} ${subscriptionId} ${appId} ${appSecret} ${tenantId} ${resourceGroupName} ${location} ${vmName}')
    }
  }
}

// Bastion
module bastion 'br/public:avm/res/network/bastion-host:0.2.2' = if (deployBastion == 'yes') {
  name: '${prefix}-bastion'
  params: {
    name: '${prefix}-bastion'
    virtualNetworkResourceId: vnet.outputs.resourceId
  }
}

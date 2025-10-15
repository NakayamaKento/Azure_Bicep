@description(' "26100.2033.241004" "26100.2314.241107" "26100.2605.241207" "26100.2894.250113" "26100.3194.250210" "26100.3476.250306" "26100.3775.250406" "26100.4061.250510" "26100.4066.250524" "26100.4349.250607" "26100.4656.250712" "26100.4946.250810" "26100.6584.250906" "26100.6899.251011" ')
param winSer2025version string

@description('すべてのリソースに共通する接頭語です')
param prefix string

@description('リソースの場所')
param location string = resourceGroup().location

@description('Azure Arc 対応サーバーのユーザー名')
param vmUserName string = 'AzureAdmin'

@description('Azure Arc 対応サーバーのパスワード')
@secure()
param vmPassword string

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
        name: 'Allow-RDP'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '3389'
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
  name: '${prefix}-arcvm2025'
  params: {
    adminUsername: vmUserName
    adminPassword: vmPassword
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2025-datacenter-g2'
      version: winSer2025version
    }
    name: '${prefix}-arcvm2025'
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
    osType: 'Windows'
    vmSize: vmSize
    zone: 0
    // Arc 用の拡張機能
    extensionCustomScriptConfig: {
      enabled: true
      fileData: [
        {
          uri: ((useDeviceCode)
            ? 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/main/products/ArcEnabledWindowsServer2025/scripts/install_arc_agent_deviceCode.ps1'
            : 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/main/products/ArcEnabledWindowsServer2025/scripts/install_arc_agent.ps1')
        }
      ]
    }
    extensionCustomScriptProtectedSetting: {
      commandToExecute: ((useDeviceCode)
        ? 'powershell.exe -ExecutionPolicy Bypass -File install_arc_agent_deviceCode.ps1 -tenantId ${tenantId} -resourceGroup ${resourceGroupName} -subscriptionId ${subscriptionId} -location ${location} -adminUsername ${vmUserName}'
        : 'powershell.exe -ExecutionPolicy Bypass -File install_arc_agent.ps1 -appId ${appId} -password ${appSecret} -tenantId ${tenantId} -resourceGroup ${resourceGroupName} -subscriptionId ${subscriptionId} -location ${location} -adminUsername ${vmUserName}')
    }
  }
}


// Bastion
module bastion 'br/public:avm/res/network/bastion-host:0.2.2' = if (deployBastion == 'yes'){
  name: '${prefix}-bastion'
  params: {
    name: '${prefix}-bastion'
    virtualNetworkResourceId: vnet.outputs.resourceId
  }
}

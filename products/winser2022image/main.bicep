@description(' "20348.2700.240905" "20348.2762.241006" "20348.2849.241102" "20348.2966.241205" "20348.3091.250112" "20348.3207.250210" "20348.3328.250306" "20348.3561.250409" "20348.3692.250509" "20348.3695.250523" "20348.3807.250605" "20348.3932.250705" "20348.4052.250808" "20348.4171.250903" "20348.4294.251009" "20348.4297.251022" "20348.4405.251112" "20348.4529.251205" "20348.4171.250903" "20348.4291.251003" "20348.4294.251009" "20348.4297.251022" "20348.4405.251105" "20348.4529.251205" ')
param winSer2022version string

param prefix string = 'my'
param vnetAddress string = '10.0.0.0/16'
param adminUsername string = 'AzureAdmin'

@secure()
param adminPassword string

module Vnet 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: '${prefix}-vnet-deploy'
  params: {
    name: '${prefix}-vnet'
    addressPrefixes: [
      vnetAddress
    ]
    subnets:[
      {
        name: '${prefix}-subnet'
        addressPrefix: cidrSubnet(vnetAddress, 24, 0)
        networkSecurityGroupResourceId : nsg.outputs.resourceId
      }
    ]
  }
}

module nsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: '${prefix}-nsg-deploy'
  params: {
    name: '${prefix}-nsg'
    securityRules:[
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

module winser2022 'br/public:avm/res/compute/virtual-machine:0.2.3' = {
  name: '${prefix}-winser2022-deploy'
  params: {
    adminUsername: adminUsername
    adminPassword: adminPassword
    availabilityZone: 0
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: winSer2022version
    }
    name: '${prefix}-win2022'
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: '${prefix}-ip-config'
            pipConfiguration: {
              publicIpNameSuffix: '-pip'
            }
            privateIpAddressVersion: 'IPv4'
            subnetResourceId: Vnet.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic'
      }
    ]
    osDisk: {
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_D4s_v4'
  }
}

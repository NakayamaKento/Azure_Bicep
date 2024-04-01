param prefix string = 'my'
param addressPrefix string = '10.0.0.0/16'
param adminUsername string = 'AzureAdmin'

@secure()
param adminPassword string

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: '${prefix}-vnet-deploy'
  params: {
    addressPrefixes: [
      addressPrefix
    ]
    name: '${prefix}-vnet'
    subnets: [
      {
        addressPrefix: cidrSubnet(addressPrefix, 24, 0)
        name: '${prefix}-subnet'
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
    ]
  }
}

module nsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: '${prefix}-nsg-deploy'
  params: {
    name: '${prefix}-nsg'
    securityRules: [
      {
        name : 'Allow-RDP'
        properties: {
          access: 'Allow'
          description: 'Allow RDP'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          direction: 'Inbound'
          priority: 1000
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
    ]
  }
}


module windowsServer2022 'br/public:avm/res/compute/virtual-machine:0.2.3' = {
  name: '${prefix}-vm-deploy'
  params: {
    adminUsername: adminUsername
    adminPassword: adminPassword
    availabilityZone: 0 // 0 は可用性ゾーンなし
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-Datacenter'
      version: 'latest'
    }
    name: '${prefix}-win2022-vm'
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: '${prefix}-ip-config'
            pipConfiguration: {
              publicIpNameSuffix: '-pip'
            }
            privateIpAddressVersion: 'IPv4'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
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
    vmSize: 'Standard_D2s_v3'
  }
}

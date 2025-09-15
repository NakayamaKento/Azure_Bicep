@description(' "14393.6981.240504" "14393.7070.240608" "14393.7159.240703" "14393.7259.240811" "14393.7336.240830" "14393.7428.241004" "14393.7515.241101" "14393.7606.241205" "14393.7699.250109" "14393.7785.250210" "14393.7876.250306" "14393.7973.250409" "14393.8066.250511" "14393.8148.250605" "14393.8246.250703" "14393.8330.250803" "14393.8422.250904" ')
param winSer2016version string

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

module winser2016 'br/public:avm/res/compute/virtual-machine:0.2.3' = {
  name: '${prefix}-winser2016-deploy'
  params: {
    adminUsername: adminUsername
    adminPassword: adminPassword
    availabilityZone: 0
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2016-Datacenter'
      version: winSer2016version
    }
    name: '${prefix}-win2016'
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

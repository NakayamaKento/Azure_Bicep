@description(' 20348.1366.221207 20348.1487.230106 20348.1547.230207 20348.1607.230310 20348.1668.230404 20348.1726.230505 20348.1787.230607 20348.1787.230621 20348.1850.230707 20348.1906.230803 20348.1970.230905 20348.2031.231006 20348.2113.231109 20348.2159.231202 20348.2227.240104 20348.2322.240207 20348.2340.240303 ')
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

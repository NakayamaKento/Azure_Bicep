@description('hoge')
param winSer2012version string

param location string = resourceGroup().location
param NamePrefix string = 'winser2012'
param adminUsername string = 'AzureAdmin'

@description('/24 よりも大きい値にしてください')
param vnetAddressPrefix string = '10.0.0.0/16'

@secure()
param adminPassword string



resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: '${NamePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: '${NamePrefix}-subnet'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 0)
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${NamePrefix}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: '${NamePrefix}-vm'
  location: location
  dependsOn: [
    vnet
    nsg
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS2_v2'
    }
    osProfile: {
      computerName: '${NamePrefix}-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      image: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2012-Datacenter'
        version: winSer2012version
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${NamePrefix}-nic')
        }
      ]
    }
  }
}

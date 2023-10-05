param location string = 'japaneast'
param vmName string = 'win-vm'
param vmsize string = 'Standard_D2s_v4'
param vmimagesku string = '2019-Datacenter'

@description('Windows Server 2019 の場合、2023/8 のバージョンは 17763.4737.230802 です')
param vmimageversion string = 'latest'

@secure()
param adminUsername string

@secure()
param adminPassword string

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-03-01' = {
  name: '${vmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-rdp'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: '${vmName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: '${vmName}-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmsize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: vmimagesku
        version: vmimageversion
      }
      osDisk: {
        name: '${vmName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: 128
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource bginfoExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  name: 'BGInfo'
  location: location
  parent: vm
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'BGInfo'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      logonTrigger: true
    }
  }
}

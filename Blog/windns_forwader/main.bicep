param location string = resourceGroup().location
param addressOnprem string = '10.0.0.0/16'
param addressPrimaryAzure string = '10.1.0.0/16'
param addressSecondaryAzure string = '10.2.0.0/16'
param vmUsername string = 'AzureAdmin'
@secure()
param vmPassword string


// Create Onprem
module onpreVnet 'br/public:avm/res/network/virtual-network:0.2.0' = {
  name: 'vnet-onprem'
  params: {
    name: 'vnet-onprem'
    addressPrefixes: [
      addressOnprem
    ]
    subnets: [
      {
        name: 'subnet-onprem'
        addressPrefix: cidrSubnet(addressOnprem, 24, 0)
      }
    ]
  }
} 

// Create winser DNS
module windowsDNS 'br/public:avm/res/compute/virtual-machine:0.6.0' = {
  name: 'vm-win-dns'
  params: {
    name: 'vm-win-dns'
    adminUsername: vmUsername
    adminPassword: vmPassword
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest' 
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ip-config'
            pipConfiguration: {
              publicIpNameSuffix: '-pip'
            }
            privateIpAddressVersion: 'IPv4'
            subnetResourceId: onpreVnet.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic'
      }
    ]
    osDisk: {
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_D4s_v4'
    zone: 0
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: windowsDNS.name
}

// Managed Run Command
resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2024-03-01' = {
  name: 'winserDNSruncommand'
  location: location
  parent: vm
  properties: {
    source: {
      scriptUri: 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/main/Blog/windns_forwader/installDNSscript.ps1'
    }
  }
}

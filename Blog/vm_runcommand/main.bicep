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
        name: 'AllowHttp'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
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
      sku: '2022-datacenter-azure-edition-hotpatch'
      version: 'latest'
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

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: '${prefix}-win2022'
}

// Managed Run Command
resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2024-03-01' = {
  name: '${prefix}-runcommand'
  location: resourceGroup().location
  parent: vm
  properties: {
    source: {
      //script: 'Install-WindowsFeature -Name Web-Server -IncludeManagementTools'
      //commandId: 'DisableWindowsUpdate'
      scriptUri: 'https://raw.githubusercontent.com/NakayamaKento/powershell_script/main/install_IIS.ps1'
    }
  }
}

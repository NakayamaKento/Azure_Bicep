param location string = resourceGroup().location
param suffix string = 'bicep'
@secure()
param password string
param vnetAddress string = '10.0.0.0/16'

// Log Analytics Workspace
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.14.1' = {
  params: {
    name: 'log-${suffix}'
    location: location
  }
}

// Vnet
module vnet 'br/public:avm/res/network/virtual-network:0.7.2' = {
  params: {
    name: 'vnet-${suffix}'
    location: location
    addressPrefixes: [
      vnetAddress
    ]
    subnets: [
      {
        name: 'default'
        addressPrefix: cidrSubnet(vnetAddress, 24, 0)
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
    ]
  }
}

// Network Security Group
module nsg 'br/public:avm/res/network/network-security-group:0.5.2' = {
  params: {
    name: 'nsg-${suffix}'
    location: location
    securityRules: [
     {
      name: 'allow_http'
      properties: {
        access: 'Allow'
        direction: 'Inbound'
        priority: 100
        protocol: 'Tcp'
        sourceAddressPrefix: '*'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '80'
      }
     }
    ]
  }
}

// IIS VM
module iisVm 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  params: {
    name: 'iisvm-${suffix}'
    location: location
    adminUsername: 'AzureAdmin'
    adminPassword: password
    availabilityZone: -1
    imageReference:{
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition-hotpatch'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig1'
            pipConfiguration: {
              publicIpNameSuffix: '-pip'
            }
            privateIPAddressVersion: 'IPv4'
            subnetResourceId: vnet.outputs.subnetResourceIds[0]
          }
        ]
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
    extensionCustomScriptConfig: {
      name: 'install_iis'
      settings: {
        commandToExecute: 'powershell -Command "Install-WindowsFeature -name Web-Server -IncludeManagementTools"'
      }
    }
  }
}

output vmPublicIP string = iisVm.outputs.nicConfigurations[0].ipConfigurations[0].publicIP

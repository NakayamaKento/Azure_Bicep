param location string = resourceGroup().location
param addressOnprem string = '10.0.0.0/16'
param vmUsername string = 'AzureAdmin'
@secure()
param vmPassword string


// Create Onprem
module onpreNSG 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: 'nsg-testonprem'
  params: {
    name: 'nsg-testonprem'
    securityRules: [
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

module onpreVnet 'br/public:avm/res/network/virtual-network:0.2.0' = {
  name: 'vnet-testonprem'
  params: {
    name: 'vnet-testonprem'
    addressPrefixes: [
      addressOnprem
    ]
    subnets: [
      {
        name: 'subnet-onprem'
        addressPrefix: cidrSubnet(addressOnprem, 24, 0)
        networkSecurityGroupResourceId: onpreNSG.outputs.resourceId
      }
    ]
    dnsServers: [
      cidrHost(cidrSubnet(addressOnprem, 24, 0), 3)
    ]
  }
} 

// Create winser DNS
module windowsDNS 'br/public:avm/res/compute/virtual-machine:0.6.0' = {
  name: 'vm-win-testdns'
  params: {
    name: 'vm-win-testdns'
    adminUsername: vmUsername
    adminPassword: vmPassword
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter'
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
  name: 'winserDNSruncommandtest'
  location: location
  parent: vm
  properties: {
    source: {
      scriptUri: 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/39-blog-windows-server-dns/Blog/windns_forwader/installDNSscript.ps1'
    }
  }
}

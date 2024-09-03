param location string = resourceGroup().location
param addressOnprem string = '10.0.0.0/16'
param addressPrimaryAzure string = '10.1.0.0/16'
param addressSecondaryAzure string = '10.2.0.0/16'
param vmUsername string = 'AzureAdmin'
@secure()
param vmPassword string


// Create Onprem
module onpreNSG 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: 'nsg-onprem'
  params: {
    name: 'nsg-onprem'
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
  name: 'vm-win-dns'
  params: {
    name: 'vm-win-dns'
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
  name: 'winserDNSruncommand'
  location: location
  parent: vm
  properties: {
    source: {
      scriptUri: 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/39-blog-windows-server-dns/Blog/windns_forwader/installDNSscript.ps1'
    }
  }
}

// Create Azure Primary
module azurePrimaryNSG 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: 'nsg-azure-primary'
  params: {
    name: 'nsg-azure-primary'
  }
}

module azurePrimaryVnet 'br/public:avm/res/network/virtual-network:0.2.0' = {
  name: 'vnet-azure-primary'
  params: {
    name: 'vnet-azure-primary'
    addressPrefixes: [
      addressPrimaryAzure
    ]
    subnets: [
      {
        name: 'subnet-azure-primary'
        addressPrefix: cidrSubnet(addressPrimaryAzure, 24, 0)
        networkSecurityGroupResourceId: azurePrimaryNSG.outputs.resourceId
      }
      {
        name: 'subnet-azure-primary-inbound'
        addressPrefix: cidrSubnet(addressPrimaryAzure, 24, 1)
      }
    ]
    peerings:[
      {
        remoteVirtualNetworkId: onpreVnet.outputs.resourceId
        remotePeeringEnabled: true
      }
    ]
  }
}

// Create Private DNS Zone
module privateDNSBlob 'br/public:avm/res/network/private-dns-zone:0.5.0' = {
  name: 'privatedns-zone'
  params: {
    name: 'privatelink.blob.core.windows.net'
    virtualNetworkLinks: [
      {
        registrationEnabled: true
        virtualNetworkResourceId: azurePrimaryVnet.outputs.resourceId
      }
    ]
  }
}

// Create Blob Storage
module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
  name: 'storageaccount'
  params: {
    name: '${uniqueString(resourceGroup().id)}blob'
    kind: 'StorageV2'
    location: location
    skuName: 'Standard_LRS'
    privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          privateDNSBlob.outputs.resourceId
        ]
        service: 'blob'
        subnetResourceId: azurePrimaryVnet.outputs.subnetResourceIds[0]
      }
    ]
  }
}

// DNS Private Resolver
module primaryDNSresolver 'br/public:avm/res/network/dns-resolver:0.4.0' = {
  name: 'dns-resolver-primary'
  params: {
    name: 'dns-resolver-primary'
    virtualNetworkResourceId: azurePrimaryVnet.outputs.resourceId
    inboundEndpoints:[
      {
        name: 'dns-resolver-primary-inbound'
        subnetResourceId: azurePrimaryVnet.outputs.subnetResourceIds[1]
      }
    ] 
  }
}


// Create Azure Secondary
module azureSecondaryNSG 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: 'nsg-azure-secondary'
  params: {
    name: 'nsg-azure-secondary'
  }
}

module azureSecondaryVnet 'br/public:avm/res/network/virtual-network:0.2.0' = {
  name: 'vnet-azure-secondary'
  params: {
    name: 'vnet-azure-secondary'
    addressPrefixes: [
      addressSecondaryAzure
    ]
    subnets: [
      {
        name: 'subnet-azure-secondary'
        addressPrefix: cidrSubnet(addressSecondaryAzure, 24, 0)
        networkSecurityGroupResourceId: azureSecondaryNSG.outputs.resourceId
      }
      {
        name: 'subnet-azure-secondary-inbound'
        addressPrefix: cidrSubnet(addressSecondaryAzure, 24, 1)
      }
    ]
    peerings:[
      {
        remoteVirtualNetworkId: onpreVnet.outputs.resourceId
        remotePeeringEnabled: true
      }
    ]
  }
}

module secondaryDNSresolver 'br/public:avm/res/network/dns-resolver:0.4.0' = {
  name: 'dns-resolver-secondary'
  params: {
    name: 'dns-resolver-secondary'
    virtualNetworkResourceId: azureSecondaryVnet.outputs.resourceId
    inboundEndpoints:[
      {
        name: 'dns-resolver-primary-inbound'
        subnetResourceId: azureSecondaryVnet.outputs.subnetResourceIds[1]
      }
    ] 
  }
}

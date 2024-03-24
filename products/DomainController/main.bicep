param resourceNamePrefix string = 'kenakay'
param vnetAddressPrefix string = '10.0.0.0/16'
param adAdminUserName string = 'AzureAdmin'
param adAdminPassword string

//var dnsServerAddress

// create vnet by Azure verified module
module vnet 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: 'deploy-${resourceNamePrefix}-vnet'
  params: {
    addressPrefixes: [
      vnetAddressPrefix
    ]
    name: '${resourceNamePrefix}-vnet'
    subnets: [
      {
        addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 0)
        name: 'ad-subnet'
      }
    ]
  }
}

// create domain controller vm by Azure verified module
module advm 'br/public:avm/res/compute/virtual-machine:0.2.2' = {
  name: 'deploy-advm'
  params: {
    adminUsername: adAdminUserName
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    name: 'advm'
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: vnet.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_DS2_v2'
    encryptionAtHost: false
    adminPassword:adAdminPassword
  }
}


output subnetResourceIds array = vnet.outputs.subnetResourceIds

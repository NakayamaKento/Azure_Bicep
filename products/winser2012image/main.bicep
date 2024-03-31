@description(' 3.127.20190214 9200.23920.221007 9200.23968.221105 9200.24018.221202 9200.24075.230107 9200.24116.230208 9200.24168.230311 9200.24216.230330 9200.24266.230505 9200.24314.230531 9200.24314.230621 9200.24374.230707 9200.24414.230802 9200.24462.230825 9200.24523.231004 9200.23920.221007 9200.23968.221105 9200.24018.221202 9200.24075.230107 9200.24116.230208 9200.24168.230311 9200.24216.230330 9200.24266.230505 9200.24314.230531 9200.24314.230621 9200.24374.230707 9200.24414.230802 9200.24462.230825 9200.24523.231004 3.127.20181010 3.127.20190214 3.127.20190314 3.127.20190410 9200.23920.221007 9200.23968.221105 9200.24018.221202 9200.24075.230107 9200.24116.230208 9200.24168.230311 9200.24216.230330 9200.24266.230505 9200.24314.230531 9200.24314.230621 9200.24374.230707 9200.24414.230802 9200.24462.230825 9200.24523.231004 9200.23920.221007 9200.23968.221105 9200.24018.221202 9200.24075.230107 9200.24116.230208 9200.24168.230311 9200.24216.230330 9200.24266.230505 9200.24314.230531 9200.24314.230621 9200.24374.230707 9200.24414.230802 9200.24462.230825 9200.24523.231004 9200.23920.221007 9200.23968.221105 9200.24018.221202 9200.24075.230107 9200.24116.230208 9200.24168.230311 9200.24216.230330 9200.24266.230505 9200.24314.230531 9200.24314.230621 9200.24374.230707 9200.24414.230802 9200.24462.230825 9200.24523.231004 9200.23920.221007 9200.23968.221105 9200.24018.221202 9200.24075.230107 9200.24116.230208 9200.24168.230311 9200.24216.230330 9200.24266.230505 9200.24314.230531 9200.24314.230621 9200.24374.230707 9200.24414.230802 9200.24462.230825 9200.24523.231004 ')
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
      $valReference: {
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

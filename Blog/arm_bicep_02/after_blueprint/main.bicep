param resourceGroupLocation string = resourceGroup().location
param storegeAccountName string = 'storage${uniqueString(resourceGroup().id)}'
param vnetName string = 'vnet${uniqueString(resourceGroup().id)}'

resource strogaAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name:storegeAccountName
  location:resourceGroupLocation
  kind:'StorageV2'
  sku:{
    name:'Standard_LRS'
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name:vnetName
  location:resourceGroupLocation
  properties:{
    addressSpace:{
      addressPrefixes:[
        '10.0.0.0/16'
      ]
    }
    subnet:[
      {
        name:'subnet-1'
        properties:{
          addressPrefix:'10.0.0.0/24'
        }
      }
      {
        name:'subnet-2'
        properties:{
          addressPrefix:'10.0.1.0/24'
        }
      }
    ]
  }
}

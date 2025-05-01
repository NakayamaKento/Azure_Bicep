@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

param resourceTags object

var storageAccountName = 'hcibox${uniqueString(resourceGroup().id)}'

// Create Storage Account by Azure Verified Module
module storageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  params: {
    name: storageAccountName
    location: location
    skuName: storageAccountType
    kind: 'StorageV2'
    tags: resourceTags
  }
}

output storageAccountName string = storageAccountName

param cosmosDBaccountName string = 'toyrnd-${uniqueString(resourceGroup().id)}'
param cosmosDBdataabaseThroughput int = 400
param location string = resourceGroup().location
param storageAccountName string

var cosmosDBDatabaseName = 'FlightsTests'
var cosmosDBContainerName = 'FlightsTests'
var cosmosDBContainerPartitionKey = '/droneId'
var logAnalyticsWorkspaceName = 'ToyLogs'
var cosmosDBAccountDiagnosticSettingName = 'route-logs-to-log-analytics'
var StorageAccountBlogDiagnosticsSettingName = 'route-logs-to-log-analytics'

resource cosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2020-04-01' = {
  name: cosmosDBaccountName
  location: location
  properties: {
   databaseAccountOfferType: 'Standard'
   locations: [
     {
       locationName: location
     }
   ]
  }
}


resource cosmosDBDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2020-04-01' = {
  parent:cosmosDBAccount
  name: cosmosDBDatabaseName
  properties: {
    resource: {
      id: cosmosDBDatabaseName
    }
    options: {
      throughput: cosmosDBdataabaseThroughput
    }
  }

  resource  container 'containers' = {
    name : cosmosDBContainerName
    properties:{
      resource:{
        id: cosmosDBContainerName
        partitionKey:{
          kind: 'Hash'
          paths:[
            cosmosDBContainerPartitionKey
          ]
        }
      }
      options:{}
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' existing = {
  name: logAnalyticsWorkspaceName
}

resource cosmosDBAccountDiagnostics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  scope: cosmosDBAccount
  name: cosmosDBAccountDiagnosticSettingName
  properties:{
    workspaceId: logAnalyticsWorkspace.id
    logs:[
      {
        category: 'DataPlaneRequests'
        enabled: true
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: storageAccountName

  resource blobService 'blobServices' existing = {
    name: 'defualt'
  }
}

resource storageAccountBlobDiagnostics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  scope: storageAccount::blobService
  name: StorageAccountBlogDiagnosticsSettingName
  properties:{
    workspaceId: logAnalyticsWorkspace.id
    logs:[
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}

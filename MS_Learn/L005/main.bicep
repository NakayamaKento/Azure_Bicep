param cosmosDBaccountName string = 'toyrnd-${uniqueString(resourceGroup().id)}'
param cosmosDBdataabaseThroughput int = 400
param location string = resourceGroup().location

var cosmosDBDatabaseName = 'FlightsTests'
var cosmosDBContainerName = 'FlightsTests'
var cosmosDBPartitionKey = '/droneId'

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
}

// ↑ の中に入れ子でリソースを追加する所から

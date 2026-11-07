@description('Azure region for the virtual network, Network Watcher, and monitoring resources.')
param location string = 'eastasia'

@description('Prefix used for resource names.')
@minLength(1)
@maxLength(20)
param prefix string = 'vnetflowv5'

@description('Name of the Network Watcher in this deployment resource group.')
param networkWatcherName string = 'NetworkWatcher_${location}'

@description('Name of the virtual network flow log.')
param flowLogName string = '${prefix}-flowlog'

@description('Virtual network address space.')
param vnetAddressPrefix string = '10.0.0.0/16'

var storageAccountName = 'vnetflow${uniqueString(subscription().id, resourceGroup().id)}'

resource networkWatcher 'Microsoft.Network/networkWatchers@2024-10-01' existing = {
  name: networkWatcherName
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-10-01' = {
  name: '${prefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 0)
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${prefix}-law'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource flowLog 'Microsoft.Network/networkWatchers/flowLogs@2024-10-01' = {
  parent: networkWatcher
  name: flowLogName
  location: location
  properties: {
    enabled: true
    targetResourceId: virtualNetwork.id
    storageId: storageAccount.id
    retentionPolicy: {
      days: 30
      enabled: true
    }
    format: {
      type: 'JSON'
      version: 5
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        trafficAnalyticsInterval: 10
        workspaceId: logAnalyticsWorkspace.properties.customerId
        workspaceRegion: location
        workspaceResourceId: logAnalyticsWorkspace.id
      }
    }
  }
}

output virtualNetworkId string = virtualNetwork.id
output storageAccountName string = storageAccount.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output flowLogResourceId string = flowLog.id

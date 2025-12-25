param location string = resourceGroup().location
param suffix string = 'bicep'

// Data Collection Rule
resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-${suffix}'
  location: location
  properties: {
    dataSources: {
      iisLogs: [
        {
          streams: [
            'Microsoft-W3CIISLog'
          ]
          name: 'iisLogsDataSource'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalytics.id
          name: 'logAnalyticsDestination'
        }
      ]
    }
    dataFlows: [
      {
        destinations: [
          'logAnalyticsDestination'
        ]
        outputStream: 'Microsoft-W3CIISLog'
        streams: [
          'Microsoft-W3CIISLog'
        ]
        transformKql: 'source'
      }
    ]
  }
}

// Reference existing Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: 'log-${suffix}'
}

// Reference existing VM
resource iisVm 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: 'iisvm-${suffix}'
}

// Data Collection Rule Association
resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'dcra-${suffix}'
  scope: iisVm
  properties: {
    dataCollectionRuleId: dcr.id
  }
}

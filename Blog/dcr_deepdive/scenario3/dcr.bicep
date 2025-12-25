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
        transformKql: 'source | where scStatus  !in ("200", "304") | extend ErrorCategory = case(scStatus startswith "4", "ClientError", scStatus startswith "5", "ServerError", "Other") | project TimeGenerated, Computer, sSiteName, csMethod, csUriStem, scStatus, scWin32Status, TimeTaken, csUserAgent, ErrorCategory'
      }
      // 2つ目の dataFlow を追加し、カスタムテーブルへ送信
      {
        destinations: [
          'logAnalyticsDestination'
        ]
        outputStream: 'Custom-iislog_CL'
        streams: [
          'Microsoft-W3CIISLog'
        ]
        transformKql: 'source | project TimeGenerated, cIP, scStatus'
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

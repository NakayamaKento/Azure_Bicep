@description('Name for your log analytics workspace')
param workspaceName string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('SKU, leave default pergb2018')
param sku string = 'pergb2018'

param resourceTags object

var automationAccountName = 'HCIBox-Automation-${uniqueString(resourceGroup().id)}'
var automationAccountLocation = ((location == 'eastus') ? 'eastus2' : ((location == 'eastus2') ? 'eastus' : location))

// Create a Log Analytics Workspace by Azure Verified Module
module workspace 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  params: {
    name: workspaceName
    location: location
    skuName: sku
    tags: resourceTags
  }
}

// Create a Automation Account by Azure Verified Module
module automationAccount 'br/public:avm/res/automation/automation-account:0.14.1' = {
  params: {
    name: automationAccountName
    location: automationAccountLocation
    skuName: 'Basic'
    tags: resourceTags
  }
  dependsOn: [
    workspace
  ]
}

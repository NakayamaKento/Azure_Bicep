// Parameters
param location string = resourceGroup().location
param prefix string = 'logaplan'
param vnetAddress string = '10.0.0.0/16'
param adminUsername string = 'AzureAdmin'

@secure()
param adminPassword string

// Variables
var logAnalyticsWorkspaceName = '${prefix}-law'
var customTableName = 'CustomTable_CL'
var userAssignedIdentityName = '${prefix}-identity'
var roleAssignmentName = guid(resourceGroup().id, 'contributor')
var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var deploymentScriptName = '${prefix}-create-table-script'

// Create Network Security Group
module nsg 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: '${prefix}-nsg-deploy'
  params: {
    name: '${prefix}-nsg'
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Create Virtual Network
module vnet 'br/public:avm/res/network/virtual-network:0.2.0' = {
  name: '${prefix}-vnet-deploy'
  params: {
    name: '${prefix}-vnet'
    addressPrefixes: [
      vnetAddress
    ]
    subnets: [
      {
        name: '${prefix}-subnet'
        addressPrefix: cidrSubnet(vnetAddress, 24, 0)
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
    ]
  }
}

// Create Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Create Windows VM
module windowsVM 'br/public:avm/res/compute/virtual-machine:0.6.0' = {
  name: '${prefix}-vm-deploy'
  params: {
    name: '${prefix}-vm'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: '${prefix}-ip-config'
            pipConfiguration: {
              publicIpNameSuffix: '-pip'
            }
            privateIpAddressVersion: 'IPv4'
            subnetResourceId: vnet.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic'
      }
    ]
    osDisk: {
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_D4s_v4'
    zone: 0
  }
}

// Create Managed Identity for Deployment Script
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userAssignedIdentityName
  location: location
}

// Assign Contributor role to Managed Identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deployment Script to create custom table in Log Analytics
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: deploymentScriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'WorkspaceId'
        value: logAnalyticsWorkspace.properties.customerId
      }
      {
        name: 'WorkspaceName'
        value: logAnalyticsWorkspaceName
      }
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'TableName'
        value: customTableName
      }
    ]
    scriptContent: '''
      # Install required modules
      Install-Module -Name Az.OperationalInsights -Force -AllowClobber -Scope CurrentUser
      
      # Connect using Managed Identity
      Connect-AzAccount -Identity
      
      # Create custom table schema
      $tableSchema = @{
        properties = @{
          schema = @{
            name = $env:TableName
            columns = @(
              @{
                name = "TimeGenerated"
                type = "datetime"
              }
              @{
                name = "RawData"
                type = "string"
              }
              @{
                name = "EventLevel"
                type = "string"
              }
              @{
                name = "EventMessage"
                type = "string"
              }
            )
          }
          retentionInDays = 30
          plan = "Analytics"
        }
      }
      
      # Convert to JSON
      $tableJson = $tableSchema | ConvertTo-Json -Depth 10
      
      Write-Output "Creating custom table: $env:TableName"
      Write-Output "Table Schema: $tableJson"
      
      # Create the table using REST API
      $managementUrl = (Get-AzEnvironment -Name (Get-AzContext).Environment).ResourceManagerUrl
      $workspaceResourceId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$env:ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$env:WorkspaceName"
      $tableUri = "${managementUrl}${workspaceResourceId}/tables/${env:TableName}?api-version=2022-10-01"
      
      $token = (Get-AzAccessToken -ResourceUrl $managementUrl).Token
      $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
      }
      
      try {
        $response = Invoke-RestMethod -Uri $tableUri -Method Put -Headers $headers -Body $tableJson
        Write-Output "Custom table created successfully"
        $DeploymentScriptOutputs = @{}
        $DeploymentScriptOutputs['tableName'] = $env:TableName
        $DeploymentScriptOutputs['status'] = 'Success'
      } catch {
        Write-Error "Failed to create custom table: $_"
        throw
      }
    '''
  }
  dependsOn: [
    roleAssignment
  ]
}

// Get reference to the VM resource
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: windowsVM.outputs.name
}

// Create Data Collection Endpoint
resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = {
  name: '${prefix}-dce'
  location: location
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// Create Data Collection Rule
resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: '${prefix}-dcr'
  location: location
  properties: {
    dataCollectionEndpointId: dataCollectionEndpoint.id
    streamDeclarations: {
      'Custom-MyTableStream': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'RawData'
            type: 'string'
          }
          {
            name: 'EventLevel'
            type: 'string'
          }
          {
            name: 'EventMessage'
            type: 'string'
          }
        ]
      }
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: 'lawDestination'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-MyTableStream'
        ]
        destinations: [
          'lawDestination'
        ]
        transformKql: 'source'
        outputStream: 'Custom-${customTableName}'
      }
    ]
  }
  dependsOn: [
    deploymentScript
  ]
}

// Associate Data Collection Rule with VM
resource dataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: '${prefix}-dcra'
  scope: vm
  properties: {
    dataCollectionRuleId: dataCollectionRule.id
    description: 'Association between DCR and VM'
  }
}

// Outputs
output virtualNetworkId string = vnet.outputs.resourceId
output vmName string = windowsVM.outputs.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output customTableName string = customTableName
output dataCollectionRuleName string = dataCollectionRule.name
output dataCollectionEndpointName string = dataCollectionEndpoint.name

// Parameters
param location string = resourceGroup().location
param prefix string = 'logaplan'
param vnetAddress string = '10.0.0.0/16'
param adminUsername string = 'AzureAdmin'

@secure()
param adminPassword string

// Variables
var logAnalyticsWorkspaceName = '${prefix}-law'
var userAssignedIdentityName = '${prefix}-identity'
var roleAssignmentName = guid(resourceGroup().id, 'contributor')
var contributorRoleDefinitionId = resourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b24988ac-6180-42a0-ab88-20f7382dd24c'
)
var deploymentScriptName = '${prefix}-create-table-script'
var storageAccountName = '${replace(prefix, '-', '')}sa${uniqueString(resourceGroup().id)}'
// scripts を格納するコンテナ/パスは後から変更できるように変数化
// 例: 'scripts' や 'scripts/imds'
// GitHub Raw への URL は後から変更しやすいように変数化
// ここでは customlog.ps1 を公開している URL を指定
var customLogScriptUri = 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/refs/heads/copilot/create-log-analytics-table-plan/Blog/log_analytics_table_plan/customlog.ps1'
// 起動時タスク登録用スクリプト (register-imds-startup.ps1) の URL も変数化しておく想定
// 実際には別ファイルとして公開するか、必要に応じて修正してください
var registerStartupScriptUri = 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/refs/heads/copilot/create-log-analytics-table-plan/Blog/log_analytics_table_plan/register-imds-startup.ps1'

// Create Network Security Group
module nsg 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: '${prefix}-nsg-deploy'
  params: {
    name: '${prefix}-nsg'
    location: location
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
    location: location
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

// Create Storage Account for Deployment Script
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
    allowSharedKeyAccess: true
  }
  tags: {
    SecurityControl: 'Ignore'
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
module windowsVM 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: '${prefix}-vm-deploy'
  params: {
    name: '${prefix}-vm'
    location: location
    availabilityZone: -1
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
    extensionMonitoringAgentConfig: {
      dataCollectionRuleAssociations: [
        {
          dataCollectionRuleResourceId: dataCollectionRule.id
          name: 'SendLogToLAW'
        }
      ]
      enabled: true
      name: 'myMonitoringAgent'
    }
    // Custom Script Extension で行うのは「スクリプトの配置と起動時タスク登録のみ」
    // 実際の常駐実行は Windows のスケジュールタスクに任せる
    extensionCustomScriptConfig: {
      name: 'CustomLogSetup'
      settings: {
        fileUris: [
          customLogScriptUri
          registerStartupScriptUri
        ]
        commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Path C:\\Scripts -Force | Out-Null; Copy-Item -Path .\\customlog.ps1 -Destination C:\\Scripts\\customlog.ps1 -Force; Copy-Item -Path .\\register-imds-startup.ps1 -Destination C:\\Scripts\\register-imds-startup.ps1 -Force; & C:\\Scripts\\register-imds-startup.ps1"'
      }
    }
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
    storageAccountSettings: {
      storageAccountName: storageAccount.name
      storageAccountKey: storageAccount.listKeys().keys[0].value
    }
    environmentVariables: [
      {
        name: 'WorkspaceName'
        value: logAnalyticsWorkspaceName
      }
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'SubscriptionId'
        value: subscription().subscriptionId
      }
    ]
    scriptContent: '''
    $WorkspaceName     = $env:WorkspaceName
  $ResourceGroupName = $env:ResourceGroupName
  $SubscriptionId    = $env:SubscriptionId
      # Connect using Managed Identity
      Connect-AzAccount -Identity

      $ApiVersion = "2023-01-01-preview"
      $BasePath   = "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroupName/providers/microsoft.operationalinsights/workspaces/$WorkspaceName"


      # Create Auxiliary Table customtext_analysis_CL in Log Analytics Workspace
$tableParams = @'
{
    "properties": {
        "schema": {
               "name": "customtext_auxiliary_CL",
               "columns": [
                    {
                        "name": "TimeGenerated",
                        "type": "DateTime"
                    },
                    {
                        "name": "RawData",
                        "type": "string"
                    }
              ]
        },
        "plan": "Auxiliary"
    }
}
'@

Invoke-AzRestMethod -Path "$BasePath/tables/customtext_auxiliary_CL?api-version=$ApiVersion" -Method PUT -payload $tableParams

# Create Basic Table customtext_basic_CL in Log Analytics Workspace
$tableParams = @'
{
    "properties": {
        "schema": {
               "name": "customtext_basic_CL",
               "columns": [
                    {
                        "name": "TimeGenerated",
                        "type": "DateTime"
                    },
                    {
                        "name": "RawData",
                        "type": "string"
                    }
              ]
        },
        "plan": "Basic"
    }
}
'@

Invoke-AzRestMethod -Path "$BasePath/tables/customtext_basic_CL?api-version=$ApiVersion" -Method PUT -payload $tableParams      

# Create Analytics Table customtext_analysis_CL in Log Analytics Workspace
$tableParams = @'
{
    "properties": {
        "schema": {
               "name": "customtext_analysis_CL",
               "columns": [
                    {
                        "name": "TimeGenerated",
                        "type": "DateTime"
                    },
                    {
                        "name": "RawData",
                        "type": "string"
                    }
              ]
        },
        "plan": "Analytics"
    }
}
'@

Invoke-AzRestMethod -Path "$BasePath/tables/customtext_analysis_CL?api-version=$ApiVersion" -Method PUT -payload $tableParams      
 
    '''
  }
  dependsOn: [
    roleAssignment
  ]
}

// Create Data Collection Rule
resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: '${prefix}-dcr'
  location: location
  properties: {
    streamDeclarations: {
      // 収集するデータのうち、定義する必要があるカスタム データ。Log Analytics 側でのテーブル定義との対応は transformKql 内で行う
      'Custom-Text-customtext_analysis_CL': {
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
            name: 'FilePath'
            type: 'string'
          }
          {
            name: 'Computer'
            type: 'string'
          }
        ]
      }
    }
    dataFlows: [
      // Input(dataSource, streamDeclaration) と Output(destination) の対応付けと、KQL による変換定義
      {
        destinations: [
          // destination 側で定義した名前と対応
          'logAnalyticsDestination'
        ]
        outputStream: 'Custom-customtext_analysis_CL' // テーブルを指定。標準テーブルに取り込まれる場合は Microsoft-[tableName]、データがカスタム テーブルに取り込まれる場合は Custom-[tableName]
        streams: [
          // 入力ストリーム(dataSource 側で定義)
          'Custom-Text-customtext_analysis_CL'
        ]
        transformKql: 'source' // 受信したデータの変換
      }
      {
        destinations: [
          // destination 側で定義した名前と対応
          'logAnalyticsDestination'
        ]
        outputStream: 'Custom-customtext_basic_CL' // テーブルを指定。標準テーブルに取り込まれる場合は Microsoft-[tableName]、データがカスタム テーブルに取り込まれる場合は Custom-[tableName]
        streams: [
          // 入力ストリーム(dataSource 側で定義)
          'Custom-Text-customtext_analysis_CL' // analytics の stream を再利用
        ]
        transformKql: 'source' // 受信したデータの変換
      }
      {
        destinations: [
          // destination 側で定義した名前と対応
          'logAnalyticsDestination'
        ]
        outputStream: 'Custom-customtext_auxiliary_CL' // テーブルを指定。標準テーブルに取り込まれる場合は Microsoft-[tableName]、データがカスタム テーブルに取り込まれる場合は Custom-[tableName]
        streams: [
          // 入力ストリーム(dataSource 側で定義)
          'Custom-Text-customtext_analysis_CL' // analytics の stream を再利用
        ]
        transformKql: 'source' // 受信したデータの変換
      }
    ]
    dataSources: {
      // 収集するデータのうち、既知のデータ型。AMA のカスタムデータでは streamDeclarations だけでなく ここでの定義も必要
      logFiles: [
        // カスタム ログ
        {
          streams: [
            'Custom-Text-customtext_analysis_CL' // Stream 名。カスタム型の場合は、Custom-<TableName>
          ]
          filePatterns: [
            'C:\\Logs\\imds-customtext.log' // フォルダ、ファイルパターン
          ]
          format: 'text' // ログ形式。text または json
          settings: {
            // 時間のフォーマット
            text: {
              recordStartTimestampFormat: 'YYYY-MM-DD HH:MM:SS'
            }
          }
          name: 'customTextLogDataSource' // DCR 内の一意な名前
        }
      ]
    }
    destinations: {
      // データの送信先。dataFlows 側で指定した名前と対応させる
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id // Log Analytics ワークスペースのリソース ID。送信先がカスタム テーブルの場合は dataSources 側での定義も必要
          name: 'logAnalyticsDestination' // dataFlows 側で指定した名前と対応
        }
      ]
    }
  }
  dependsOn: [
    deploymentScript
  ]
}


resource vmRestart 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${prefix}-vm-restart-script'
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
    storageAccountSettings: {
      storageAccountName: storageAccount.name
      storageAccountKey: storageAccount.listKeys().keys[0].value
    }
    environmentVariables: [
      {
        name: 'vmId'
        value: windowsVM.outputs.resourceId
      }
    ]
    scriptContent: '''
    # VM のリソース ID を環境変数から取得
      $vmId = $env:vmId

      if (-not $vmId) {
        throw "環境変数 'vmId' が設定されていません。"
      }

      # マネージド ID でログイン
      Connect-AzAccount -Identity

      # リソース ID から VM を取得
      $vm = Get-AzVM -ResourceId $vmId -ErrorAction Stop

      Write-Output "Restarting VM: $($vm.Name) in RG: $($vm.ResourceGroupName)"

      # VM を再起動
      Restart-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name

      Write-Output "VM restart completed."
    '''
  }
}

// Outputs
output virtualNetworkId string = vnet.outputs.resourceId
output vmName string = windowsVM.outputs.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output dataCollectionRuleName string = dataCollectionRule.name
output storageAccountName string = storageAccount.name

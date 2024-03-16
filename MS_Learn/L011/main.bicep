targetScope = 'subscription'

var policyDefinitionName = 'DenyFandGServiceVMs'
var policyAssignmentName = 'DenyFandGServiceVMs'
var resourceGroupName = 'ToyNetworking'

// Azure Policy の定義
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2020-09-01' = {
  name: policyDefinitionName
  properties: {
    policyType: 'Custom'
    mode: 'All'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            anyOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/sku.name'
                like: 'Standard_F*'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/sku.name'
                like: 'Standard_G*'
              }
            ]
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

// Azure Policy の割り当て
// Bicep がサブスクリプション全体にデプロイされるので、明示的にスコープは記述していない
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentName
  properties: {
    policyDefinitionId: policyDefinition.id
  }
}


// リソース グループの作成
resource resourcegroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: deployment().location
}

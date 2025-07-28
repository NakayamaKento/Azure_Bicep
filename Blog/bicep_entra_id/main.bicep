extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:0.2.0-preview'
// main.bicep
param userPrincipalName string
param roleDefinitionID string = 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader role definition ID

// Microsoft Graph からユーザー情報を取得
resource targetUser 'Microsoft.Graph/users@v1.0' existing = {
  userPrincipalName: userPrincipalName
}

// リソースグループに Reader ロールを割り当て
var roleAssignmentName = guid(userPrincipalName, roleDefinitionID, resourceGroup().id)
resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalId: targetUser.id
  }
}

output assignedUserId string = targetUser.id
output assignedUserName string = targetUser.userPrincipalName
output roleAssignmentId string = readerRoleAssignment.id

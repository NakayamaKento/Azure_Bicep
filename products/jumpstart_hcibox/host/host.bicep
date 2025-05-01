@description('The name of your Virtual Machine')
param vmName string = 'HCIBox-Client'

@description('The size of the Virtual Machine')
@allowed([
  'Standard_E32s_v5'
  'Standard_E32s_v6'
])
param vmSize string = 'Standard_E32s_v5'

@description('Username for the Virtual Machine')
param windowsAdminUsername string = 'arcdemo'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version')
param windowsOSVersion string = '2025-datacenter-g2'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Resource Id of the subnet in the virtual network')
param subnetId string

param resourceTags object

@description('Client id of the service principal')
param spnClientId string

@description('Client secret of the service principal')
@secure()
param spnClientSecret string

@description('Tenant id of the service principal')
param spnTenantId string

@description('Azure AD object id for your Microsoft.AzureStackHCI resource provider')
param spnProviderId string

@description('Name for the staging storage account using to hold kubeconfig. This value is passed into the template as an output from mgmtStagingStorage.json')
param stagingStorageAccountName string

@description('Name for the environment Azure Log Analytics workspace')
param workspaceName string

@description('The base URL used for accessing artifacts and automation artifacts.')
param templateBaseUrl string

@description('Option to disable automatic cluster registration. Setting this to false will also disable deploying AKS and Resource bridge')
param registerCluster bool = true

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Option to deploy AKS-HCI with HCIBox')
param deployAKSHCI bool = true

@description('Option to deploy Resource Bridge with HCIBox')
param deployResourceBridge bool = true

@description('Public DNS to use for the domain')
param natDNS string = '8.8.8.8'

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

@description('Choice to enable automatic deployment of Azure Arc enabled HCI cluster resource after the client VM deployment is complete. Default is false.')
param autoDeployClusterResource bool = false

@description('Choice to enable automatic upgrade of Azure Arc enabled HCI cluster resource after the client VM deployment is complete. Only applicable when autoDeployClusterResource is true. Default is false.')
param autoUpgradeClusterResource bool = false

@description('Enable automatic logon into HCIBox Virtual Machine')
param vmAutologon bool = false

var encodedPassword = base64(windowsAdminPassword)
var bastionName = 'HCIBox-Bastion'
var publicIpAddressName = deployBastion == false ? '${vmName}-PIP' : '${bastionName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var osDiskType = 'Premium_LRS'
var PublicIPNoBastion = {
  id: publicIpAddress.outputs.resourceId
}

// Create Virtual Machine by Azure Verified Module
module vm 'br/public:avm/res/compute/virtual-machine:0.14.0' = {
  params: {
    name: vmName
    location: location
    tags: resourceTags
    managedIdentities: {
      systemAssigned: true
    }
    vmSize: vmSize
    osDisk: {
      name:'${vmName}-OSDisk'
      managedDisk: {
        storageAccountType: osDiskType
      }
      diskSizeGB: 1024
    }
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: windowsOSVersion
      version: 'latest'
    }
    dataDisks: [
      {
        name: 'ASHCIHost001_DataDisk_0'
        diskSizeGB: 256
        createOption: 'Empty'
        lun: 0
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'ASHCIHost001_DataDisk_1'
        diskSizeGB: 256
        createOption: 'Empty'
        lun: 1
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'ASHCIHost001_DataDisk_2'
        diskSizeGB: 256
        createOption: 'Empty'
        lun: 2
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'ASHCIHost001_DataDisk_3'
        diskSizeGB: 256
        createOption: 'Empty'
        lun: 3
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'ASHCIHost001_DataDisk_4'
        diskSizeGB: 256
        createOption: 'Empty'
        lun: 4
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'ASHCIHost001_DataDisk_5'
        diskSizeGB: 256
        createOption: 'Empty'
        lun: 5
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'ASHCIHost001_DataDisk_6'
        diskSizeGB: 256
        createOption: 'Empty'
        lun: 6
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      {
        name: 'ASHCIHost001_DataDisk_7'
        diskSizeGB: 256
        createOption: 'Empty'
        lun: 7
        caching: 'None'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    ]
    nicConfigurations:[
      {
        name: networkInterfaceName
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: subnetId
            privateIPAllocationMethod: 'Dynamic'
            pipConfiguration: {
              publicIPAddressResourceId: deployBastion == false ? PublicIPNoBastion.id : null
            }
          }
        ]
      }
    ]
    computerName: vmName
    adminUsername: windowsAdminUsername
    adminPassword: windowsAdminPassword
    provisionVMAgent: true
    enableAutomaticUpdates: false
    osType: 'Windows'
    zone: 0
    // bootstrap
    extensionCustomScriptConfig: {
      enabled: true
      fileData: [
        {
          uri:  uri(templateBaseUrl, 'artifacts/PowerShell/Bootstrap.ps1') // uri 関数で完全な URL 作成
        }
      ]
    }
    extensionCustomScriptProtectedSetting:{ // ドメインを変更したい。ここかな
        commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -adminPassword ${encodedPassword} -spnClientId ${spnClientId} -spnClientSecret ${spnClientSecret} -spnTenantId ${spnTenantId} -subscriptionId ${subscription().subscriptionId} -spnProviderId ${spnProviderId} -resourceGroup ${resourceGroup().name} -azureLocation ${location} -stagingStorageAccountName ${stagingStorageAccountName} -workspaceName ${workspaceName} -templateBaseUrl ${templateBaseUrl} -registerCluster ${registerCluster} -deployAKSHCI ${deployAKSHCI} -deployResourceBridge ${deployResourceBridge} -natDNS ${natDNS} -rdpPort ${rdpPort} -autoDeployClusterResource ${autoDeployClusterResource} -autoUpgradeClusterResource ${autoUpgradeClusterResource} -vmAutologon ${vmAutologon}'
      }
  }
}

// create public IP address for the VM by Azure Verified Module
module publicIpAddress 'br/public:avm/res/network/public-ip-address:0.8.0' = {
  params: {
    name: publicIpAddressName
    location: location
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    skuName: 'Standard'
    tags: resourceTags
  }
}


// Add role assignment for the VM: Owner role
resource vmRoleAssignment_Owner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // ロールの割り当ての名前はテナント内で一意にする必要がある
  // ここでは、リソースグループ名、VMの名前とロールの種類を組み合わせて一意の名前を生成しています
  name: guid(resourceGroup().name, vm.name, 'Microsoft.Authorization/roleAssignments', 'Owner') 
  scope: resourceGroup()
  properties: {
    principalId: vm.outputs.systemAssignedMIPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalType: 'ServicePrincipal'
  }
}

output adminUsername string = windowsAdminUsername
output publicIP string = deployBastion == false ? concat(publicIpAddress.outputs.ipAddress) : ''

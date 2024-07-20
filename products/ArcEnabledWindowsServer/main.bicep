@description('The name of you Virtual Machine.')
param vmName string = 'Arc-Win-Demo'

@description('Username for the Virtual Machine.')
param adminUsername string = 'arcdemo'

@description('Windows password for the Virtual Machine')
@secure()
param adminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version.')
param windowsOSVersion string = '2022-datacenter-g2'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool

@description('the Azure Bastion host name')
param bastionHostName string = 'Arc-Win-Demo-Bastion'

@description('The size of the VM')
param vmSize string = 'Standard_D8s_v3'

@description('Unique SPN app ID')
param appId string

@description('Unique SPN password')
@secure()
param password string

// @description('Unique SPN tenant ID')
// param tenantId string

// @description('Azure subscription ID')
// param subscriptionId string

@description('Name of the VNET')
param virtualNetworkName string = 'Arc-Win-Demo-VNET'

@description('Name of the subnet in the virtual network')
param subnetName string = 'Subnet'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'Arc-Win-Demo-NSG'
param resourceTags object = {
  Project: 'jumpstart_azure_arc_servers'
}

@description('Use device code to authenticate for Azure Arc')
param useDeviceCode bool = false

var vmName_var = concat(vmName)
var publicIpAddressName = '${vmName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var bastionSubnetName = 'AzureBastionSubnet'
// var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var bastionSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, bastionSubnetName)
var osDiskType = 'Premium_LRS'
var subnetAddressPrefix = '10.1.0.0/24'
var addressPrefix = '10.1.0.0/16'
var bastionName = concat(bastionHostName)
var bastionSubnetIpPrefix = '10.1.1.64/26'
var PublicIPNoBastion = {
  id: publicIpAddress.id
}

var tenantId = subscription().tenantId
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name

resource networkInterface 'Microsoft.Network/networkInterfaces@2018-10-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: ((!deployBastion) ? PublicIPNoBastion : null)
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
}

resource networkSecurityGroupName_allow_RDP_3389 'Microsoft.Network/networkSecurityGroups/securityRules@2022-05-01' = if (deployBastion) {
  parent: networkSecurityGroup
  name: 'allow_RDP_3389'
  properties: {
    priority: 1001
    protocol: 'TCP'
    access: 'Allow'
    direction: 'Inbound'
    sourceAddressPrefix: bastionSubnetIpPrefix
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '3389'
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-04-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetIpPrefix
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2019-02-01' = {
  name: publicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2019-03-01' = {
  name: vmName_var
  location: location
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: '${vmName_var}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName_var
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
    }
  }
}

resource vmName_ClientTools 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vm
  name: 'ClientTools'
  location: location
  tags: {
    displayName: 'Install Arc Agent'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        ((useDeviceCode) ? 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/33-arc-enabled-linux-server/products/ArcEnabledWindowsServer/scropts/install_arc_agent_deviceCode.ps1':'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/33-arc-enabled-linux-server/products/ArcEnabledWindowsServer/scropts/install_arc_agent.ps1' )
      ]
      commandToExecute: ((useDeviceCode) ? 'powershell.exe -ExecutionPolicy Bypass -File install_arc_agent_deviceCode.ps1 -tenantId ${tenantId} -resourceGroup ${resourceGroupName} -subscriptionId ${subscriptionId} -location ${location} -adminUsername ${adminUsername}' :'powershell.exe -ExecutionPolicy Bypass -File install_arc_agent.ps1 -appId ${appId} -password ${password} -tenantId ${tenantId} -resourceGroup ${resourceGroupName} -subscriptionId ${subscriptionId} -location ${location} -adminUsername ${adminUsername}')
    }
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2020-11-01' = if (deployBastion) {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetRef
          }
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

output adminUsername string = adminUsername
output publicIP string = concat(publicIpAddress.properties.ipAddress)

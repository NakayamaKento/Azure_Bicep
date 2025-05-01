@description('Name of the VNet')
param virtualNetworkName string = 'HCIBox-VNet'

@description('Name of the subnet in the virtual network')
param subnetName string = 'HCIBox-Subnet'

@description('Azure Region to deploy the Log Analytics Workspace')
param location string = resourceGroup().location

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'HCIBox-NSG'

@description('Name of the Bastion Network Security Group')
param bastionNetworkSecurityGroupName string = 'HCIBox-Bastion-NSG'

param resourceTags object

var addressPrefix = '172.16.0.0/16'
var subnetAddressPrefix = '172.16.1.0/24'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionName = 'HCIBox-Bastion'
var bastionSubnetIpPrefix = '172.16.3.64/26'
var bastionPublicIpAddressName = '${bastionName}-PIP'

// Create Virtual Network by Azure Verified Module
module arcVirtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = {
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [
      addressPrefix
    ]
    subnets: deployBastion == true ? [
      {
        name: subnetName
        addressPrefix: subnetAddressPrefix
        privateEndpointNetworkPolicies: 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
        networkSecurityGroupResourceId: networkSecurityGroup.outputs.resourceId
      }
      {
        name: bastionSubnetName
        addressPrefix: bastionSubnetIpPrefix
        networkSecurityGroupResourceId: bastionNetworkSecurityGroup.outputs.resourceId
      }
    ] :[
      {
        name:subnetName
        addressPrefix: subnetAddressPrefix
        privateEndpointNetworkPolicies: 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
        networkSecurityGroupResourceId: networkSecurityGroup.outputs.resourceId
      }
    ]
    tags: resourceTags
  }
}

// Create Network Security Group for HCIBox-Subnet by Azure Verified Module
module networkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.1' = {
  params: {
    name: networkSecurityGroupName
    location: location
  }
}

// Create Network Security Group for Bastion by Azure Verified Module
module bastionNetworkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.1' = if (deployBastion == true)  {
  params: {
    name: bastionNetworkSecurityGroupName
    location: location
    securityRules: [
      {
        name: 'bastion_allow_https_inbound'
        properties: {
          priority: 1010
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_gateway_manager_inbound'
        properties: {
          priority: 1011
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_load_balancer_inbound'
        properties: {
          priority: 1012
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_host_comms'
        properties: {
          priority: 1013
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'bastion_allow_ssh_rdp_outbound'
        properties: {
          priority: 1014
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'bastion_allow_azure_cloud_outbound'
        properties: {
          priority: 1015
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
        }
      }
      {
        name: 'bastion_allow_bastion_comms'
        properties: {
          priority: 1016
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'bastion_allow_get_session_info'
        properties: {
          priority: 1017
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
    ]
    tags: resourceTags
  }
}

// Create Public IP Address for Bastion by Azure Verified Module
module publicIpAddress 'br/public:avm/res/network/public-ip-address:0.8.0' = if (deployBastion == true)  {
  params: {
    name: bastionPublicIpAddressName
    location: location
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    skuName: 'Standard'
    tags: resourceTags
  }
}

// Create Bastion Host by Azure Verified Module
module bastionHost1 'br/public:avm/res/network/bastion-host:0.6.1' = if (deployBastion == true)  {
  params: {
    name: bastionName
    location: location
    virtualNetworkResourceId: arcVirtualNetwork.outputs.resourceId
    bastionSubnetPublicIpResourceId: publicIpAddress.outputs.resourceId
    tags: resourceTags
  }
}

output vnetId string = arcVirtualNetwork.outputs.resourceId
output subnetId string = arcVirtualNetwork.outputs.subnetResourceIds[0]

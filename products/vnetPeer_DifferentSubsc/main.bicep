targetScope = 'managementGroup'

param location string = 'japaneast'
param prefix string = 'knt'
param NetworkAddress1 string = '10.1.0.0/16'
param NetworkAddress2 string = '10.2.0.0/16'

param subscriptionID1 string
param subscriptionID2 string 

// sub1
module RG1 'br/public:avm/res/resources/resource-group:0.2.4' = {
  scope: subscription(subscriptionID1)
  name: '${prefix}-rg1'
  params: {
    name: '${prefix}-rg1'
    location: location
  }
}




module Vnet1 'br/public:avm/res/network/virtual-network:0.1.6' = {
  scope: resourceGroup(subscriptionID1, RG1.name)
  name: '${prefix}-vnet1'
  params: {
    name: '${prefix}-vnet1'
    addressPrefixes: [
      NetworkAddress1
    ]
    subnets: [
      {
        name: '${prefix}-subnet1-1'
        addressPrefix: cidrSubnet(NetworkAddress1, 24, 0)
      }
    ]
  }
}


// sub2
module RG2 'br/public:avm/res/resources/resource-group:0.2.4' = {
  scope: subscription(subscriptionID2)
  name: '${prefix}-rg2'
  params: {
    name: '${prefix}-rg2'
    location: location
  }
}



module Vnet2 'br/public:avm/res/network/virtual-network:0.1.6' = {
  scope: resourceGroup(subscriptionID2, RG2.name)
  name: '${prefix}-vnet2'
  params: {
    name: '${prefix}-vnet2'
    addressPrefixes: [
      NetworkAddress2
    ]
    subnets: [
      {
        name: '${prefix}-subnet2-1'
        addressPrefix: cidrSubnet(NetworkAddress2, 24, 0)
      }
    ]
  }
}


// Vnet1 to Vnet2 peering
module vnetpering1 'modules/vnetpeering.bicep' = {
  scope: resourceGroup(subscriptionID1, RG1.name)
  name: 'vnetpeering1'
  params: {
    peeringName: '${prefix}-vnet1-to-${prefix}-vnet2-peering'
    vnet1Name: Vnet1.name
    vnet2Id: Vnet2.outputs.resourceId
  }
}

// Vnet2 to Vnet1 peering
module vnetpering2 'modules/vnetpeering.bicep' = {
  scope: resourceGroup(subscriptionID2, RG2.name)
  name: 'vnetpeering2'
  params: {
    peeringName: '${prefix}-vnet2-to-${prefix}-vnet1-peering'
    vnet1Name: Vnet2.name
    vnet2Id: Vnet1.outputs.resourceId
  }
}


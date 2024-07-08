param vnet1Name string
param vnet2Id string
param peeringName string

resource vnet1 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnet1Name
}

resource peering1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: peeringName
  parent: vnet1
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vnet2Id
    }
  }
}


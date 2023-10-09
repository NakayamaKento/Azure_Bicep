param nsgName string

param ruleName string

@maxValue(40096)
@minValue(100)
param priority int

@allowed([
  'Inbound'
  'Outbound'
])
param direction string

@allowed([
  'Allow'
  'Deny'
])
param access string

@allowed([
  'TCP'
  'UDP'
  'ICMP'
  'Any'
])
param protocol string
param sourcePortRange string
param destinationPortRange string
param sourceAddressPrefix string
param destinationAddressPrefix string



resource existingNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = {
  name: nsgName
}


resource nsgRule 'Microsoft.Network/networkSecurityGroups/securityRules@2021-02-01' = {
  name: ruleName
  properties: {
    priority: priority
    direction: direction
    access: access
    protocol: protocol
    sourcePortRange: sourcePortRange
    destinationPortRange: destinationPortRange
    sourceAddressPrefix: sourceAddressPrefix
    destinationAddressPrefix: destinationAddressPrefix
  }
  parent: existingNsg
}




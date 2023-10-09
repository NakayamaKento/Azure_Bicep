using '../modules/nsg-rules.bicep'

param nsgName = 'mynsg'
param ruleName = 'allow-RDP'
param priority = 1000
param direction = 'Inbound'
param access = 'Allow'
param protocol = 'TCP'
param sourcePortRange = '*'
param destinationPortRange = '3389'
param sourceAddressPrefix = '0.0.0.0/0'
param destinationAddressPrefix = '10.0.0.0/16'


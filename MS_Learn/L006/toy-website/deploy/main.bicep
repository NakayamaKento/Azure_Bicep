@description('The Azure region into which the resources should be deployed')
param location string = resourceGroup().location

@descriptiont('The type of envieonment. This must be nonprod or prod')
@allowed([
    'nonprod'
    'prod'
])
param environmentType string


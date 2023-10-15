@description('The Azure region into which the resources should be deployed')
param location string = resourceGroup().location

@descriptiont('The type of envieonment. This must be nonprod or prod')
@allowed([
    'nonprod'
    'prod'
])
param environmentType string

@description('The name of the App Service app. This name must be globally unique')
param appServiceName string = 'toyweb-${uniqueString(resourceGroup().id)}'

module appService 'modules/app-service.bicep' = {
  name: 'app-service'
  params: {
    location: location
    environmentType: environmentType
    appServiceName: appServiceName
  }
}

@description('The Azure regions into which the resource should be deployed.')
param locations array = [
  'westeurope'
  'eastus'
  'eastasia'
]

@secure()
@description('The administrator username for the SQL Server.')
param sqlServerAdministratorLogin string

@secure()
@description('The administrator password for the SQL Server.')
param sqlServerAdministratorLoginPassword string

module databases 'modules/database.bicep' = [for location in locations: {
  name: 'database-${location}'
  params: {
    location: location
    sqlServerAdministratorLogin: sqlServerAdministratorLogin
    sqlServerAdministratorLoginPassword: sqlServerAdministratorLoginPassword
  }
}]

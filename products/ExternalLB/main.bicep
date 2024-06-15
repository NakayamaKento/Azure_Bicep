param Prefix string = 'my'
param NetAddress string = '10.0.0.0/24'
param AdminUsername string = 'AzureAdmin'

@secure()
param AdminPassword string

var VnetAddress = NetAddress
var SubnetAddress = cidrSubnet(NetAddress, 24, 0)

// Create a virtual network
module vnet 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: '${Prefix}-vnet-deploy'
  params: {
    name: '${Prefix}-vnet'
    addressPrefixes: [
      VnetAddress
    ]
    subnets: [
      {
        name: '${Prefix}-subnet'
        addressPrefix: SubnetAddress
      }
    ]
  }
}

// Create a public IP address
module publicIP 'br/public:avm/res/network/public-ip-address:0.4.1' = {
  name: '${Prefix}-pip-deploy'
  params: {
    name: '${Prefix}-pip'
  }
}

// Create a load balancer
module exLoadbalancer 'br/public:avm/res/network/load-balancer:0.1.4' = {
  name: '${Prefix}-exlb-deploy'
  params: {
    name: '${Prefix}-exlb'
    frontendIPConfigurations:[
      {
        name: '${Prefix}-exlb-fip'
        publicIPAddressId: publicIP.outputs.resourceId
      }
    ]
    backendAddressPools:[
      {
        name: '${Prefix}-exlb-bap'
      }
    ]
    loadBalancingRules: [
      {
        name: '${Prefix}-exlb-lbr'
        backendAddressPoolName: '${Prefix}-exlb-bap'
        backendPort: 80
        frontendIPConfigurationName: '${Prefix}-exlb-fip'
        frontendPort: 80
        probeName: '${Prefix}-exlb-probe'
        protocol: 'Tcp'
      }
    ]
    probes: [
      {
        intervalInSeconds: 10
        name: '${Prefix}-exlb-probe'
        numberOfProbes: 5
        port: 80
        protocol: 'Http'
        requestPath: '/'
      }
    ]
  }
}

// Create a virtual machine
module vm 'br/public:avm/res/compute/virtual-machine:0.5.0' = {
  name: '${Prefix}-vm-deploy'
  params: {
    adminUsername: AdminUsername
    adminPassword: AdminPassword
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    name: '${Prefix}-vm'
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: '${Prefix}-nic-ipconfig'
            subnetResourceID: vnet.outputs.subnetResourceIds[0]
            loadBalancerBackendAddressPools: [
              {
                id: exLoadbalancer.outputs.backendpools[0].id
              }
            ]
          }
        ]
        nicSuffix : '-nic'
      }
    ]
    osDisk: {
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_D4s_v4'
    zone: 0
  }
}

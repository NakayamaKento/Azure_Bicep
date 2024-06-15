param Prefix string = 'my'
param NetAddress string = '10.0.0.0/24'
param AdminUsername string = 'AzureAdmin'

@secure()
param AdminPassword string

var VnetAddress = NetAddress
var SubnetAddress = cidrSubnet(NetAddress, 24, 0)

module nsg 'br/public:avm/res/network/network-security-group:0.2.0' = {
  name: '${Prefix}-nsg-deploy'
  params: {
    name: '${Prefix}-nsg'
    securityRules:[
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
        }
      }
    ]
  }
}

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
        networkSecurityGroupResourceId: nsg.outputs.resourceId
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
    // VM カスタム拡張機能のスクリプトを GitHub からダウンロードするため
    outboundRules:[
      {
        allocatedOutboundPorts: 63984
        backendAddressPoolName: '${Prefix}-exlb-bap'
        frontendIPConfigurationName: '${Prefix}-exlb-fip'
        name: 'outboundRule1'
      }
    ]
  }
}


// Create a virtual machine
module vm 'br/public:avm/res/compute/virtual-machine:0.5.0' = {
  name: '${Prefix}-vm'
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
    extensionCustomScriptConfig: {
      enabled: true
      fileData: [
        {
          uri: 'https://raw.githubusercontent.com/NakayamaKento/Azure_Bicep/main/Blog/vm_customscript/installiis.ps1'
        }
      ]
    }
    extensionCustomScriptProtectedSetting: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File installiis.ps1'
    }
  }
}

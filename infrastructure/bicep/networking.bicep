// Network infrastructure for WordPress backend isolation
// VNet with subnets and security groups for private hosting

@description('Resource name prefix')
param resourceNamePrefix string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

// Variables
var vnetName = '${resourceNamePrefix}-vnet'
var containerSubnetName = 'container-subnet'
var databaseSubnetName = 'database-subnet'
var cacheSubnetName = 'cache-subnet'
var gatewaySubnetName = 'gateway-subnet'

// Network Security Groups
resource containerNsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: '${resourceNamePrefix}-container-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          description: 'Allow HTTPS traffic from internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPInbound'
        properties: {
          description: 'Allow HTTP traffic from internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1010
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowVnetInbound'
        properties: {
          description: 'Allow traffic from VNet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1020
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource databaseNsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: '${resourceNamePrefix}-database-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowMySQLFromContainers'
        properties: {
          description: 'Allow MySQL traffic from container subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource cacheNsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: '${resourceNamePrefix}-cache-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRedisFromContainers'
        properties: {
          description: 'Allow Redis traffic from container subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6380'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: containerSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: containerNsg.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: databaseSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: databaseNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'Microsoft.DBforMySQL/flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforMySQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: cacheSubnetName
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: cacheNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: gatewaySubnetName
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
}

// Private DNS Zone for MySQL
resource mysqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${resourceNamePrefix}.mysql.database.azure.com'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to VNet
resource mysqlPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: mysqlPrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private DNS Zone for Redis
resource redisPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  tags: tags
}

// Link Redis Private DNS Zone to VNet
resource redisPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: redisPrivateDnsZone
  name: '${vnetName}-redis-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Application Gateway for internal load balancing (optional)
resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${resourceNamePrefix}-agw-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: '${resourceNamePrefix}-agw'
    }
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output containerSubnetId string = '${vnet.id}/subnets/${containerSubnetName}'
output databaseSubnetId string = '${vnet.id}/subnets/${databaseSubnetName}'
output cacheSubnetId string = '${vnet.id}/subnets/${cacheSubnetName}'
output gatewaySubnetId string = '${vnet.id}/subnets/${gatewaySubnetName}'
output mysqlPrivateDnsZoneId string = mysqlPrivateDnsZone.id
output redisPrivateDnsZoneId string = redisPrivateDnsZone.id
output appGatewayPublicIpId string = appGatewayPublicIp.id
output containerNsgId string = containerNsg.id
output databaseNsgId string = databaseNsg.id
output cacheNsgId string = cacheNsg.id

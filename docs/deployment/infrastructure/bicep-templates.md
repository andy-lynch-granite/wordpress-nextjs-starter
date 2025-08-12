# Infrastructure as Code with Azure Bicep Templates

This guide provides comprehensive Infrastructure as Code (IaC) templates using Azure Bicep for deploying and managing the headless WordPress + Next.js solution.

## Prerequisites

- Azure CLI 2.40+ with Bicep extension
- PowerShell 7+ or Bash
- Git for version control
- Azure subscription with appropriate permissions

## Bicep Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Infrastructure as Code Structure                    │
└─────────────────────────────────────────────────────────────────────┘
                                        │
               ┌──────────────────────────┴─────────────────────────┐
               │                                                        │
               ▼                                                        ▼
     ┌──────────────────────┐                        ┌──────────────────────┐
     │   Main Templates      │                        │   Module Library      │
     │                      │                        │                      │
     │   - main.bicep        │                        │   - database.bicep     │
     │   - production.bicep   │                        │   - storage.bicep      │
     │   - staging.bicep      │                        │   - networking.bicep   │
     │   - development.bicep  │                        │   - monitoring.bicep   │
     └──────────────────────┘                        └──────────────────────┘
                                                                    │
                                                                    ▼
                                              ┌──────────────────────────────────────────────────┐
                                              │           Parameter Files                     │
                                              │                                              │
                                              │   - production.parameters.json              │
                                              │   - staging.parameters.json                 │
                                              │   - development.parameters.json             │
                                              └──────────────────────────────────────────────────┘
```

## Step 1: Project Structure Setup

### 1.1 Create Bicep Directory Structure

```bash
# Create Bicep infrastructure directory structure
mkdir -p infrastructure/bicep/{main,modules,parameters,scripts}

# Navigate to bicep directory
cd infrastructure/bicep

# Create subdirectories for organization
mkdir -p modules/{networking,database,storage,compute,monitoring,security}
mkdir -p parameters/{production,staging,development}
mkdir -p scripts/{deploy,validate,cleanup}

echo "Bicep project structure created"
```

### 1.2 Install Azure Bicep CLI

```bash
# Install Bicep CLI (if not already installed)
az bicep install

# Verify installation
az bicep version

# Upgrade to latest version
az bicep upgrade

echo "Bicep CLI ready"
```

## Step 2: Core Module Templates

### 2.1 Networking Module

```bash
cat > modules/networking/vnet.bicep << 'EOF'
@description('Virtual Network for WordPress + Next.js infrastructure')

// Parameters
@description('The name of the virtual network')
param vnetName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('Address prefix for the virtual network')
param addressPrefix string = '10.0.0.0/16'

@description('Environment name (dev, staging, prod)')
param environment string

@description('Project name for resource naming')
param projectName string

// Variables
var subnets = [
  {
    name: 'subnet-wordpress'
    addressPrefix: '10.0.1.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  {
    name: 'subnet-database'
    addressPrefix: '10.0.2.0/24'
    delegations: [
      {
        name: 'Microsoft.DBforMySQL/flexibleServers'
        properties: {
          serviceName: 'Microsoft.DBforMySQL/flexibleServers'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  {
    name: 'subnet-redis'
    addressPrefix: '10.0.3.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  {
    name: 'subnet-appgateway'
    addressPrefix: '10.0.4.0/24'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  {
    name: 'subnet-private-endpoints'
    addressPrefix: '10.0.5.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
]

var commonTags = {
  Project: projectName
  Environment: environment
  ManagedBy: 'Bicep'
  CreatedDate: utcNow('yyyy-MM-dd')
}

// Resources
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
        privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
        delegations: contains(subnet, 'delegations') ? subnet.delegations : []
      }
    }]
    enableDdosProtection: environment == 'prod' ? true : false
  }
}

// Network Security Groups
resource nsgWordPress 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'nsg-wordpress-${environment}'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAll'
        properties: {
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

resource nsgDatabase 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'nsg-database-${environment}'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowMySQL'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAll'
        properties: {
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

// Associate NSGs with subnets
resource subnetWordPressNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  parent: virtualNetwork
  name: 'subnet-wordpress'
  properties: {
    addressPrefix: '10.0.1.0/24'
    networkSecurityGroup: {
      id: nsgWordPress.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource subnetDatabaseNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  parent: virtualNetwork
  name: 'subnet-database'
  properties: {
    addressPrefix: '10.0.2.0/24'
    networkSecurityGroup: {
      id: nsgDatabase.id
    }
    delegations: [
      {
        name: 'Microsoft.DBforMySQL/flexibleServers'
        properties: {
          serviceName: 'Microsoft.DBforMySQL/flexibleServers'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// Outputs
output vnetId string = virtualNetwork.id
output vnetName string = virtualNetwork.name
output subnetIds object = {
  wordpress: virtualNetwork.properties.subnets[0].id
  database: virtualNetwork.properties.subnets[1].id
  redis: virtualNetwork.properties.subnets[2].id
  appgateway: virtualNetwork.properties.subnets[3].id
  privateEndpoints: virtualNetwork.properties.subnets[4].id
}
output nsgIds object = {
  wordpress: nsgWordPress.id
  database: nsgDatabase.id
}
EOF
```

### 2.2 Database Module

```bash
cat > modules/database/mysql.bicep << 'EOF'
@description('MySQL Flexible Server for WordPress')

// Parameters
@description('The name of the MySQL server')
param serverName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('MySQL administrator username')
param administratorLogin string

@description('MySQL administrator password')
@secure()
param administratorLoginPassword string

@description('MySQL server SKU')
param skuName string = 'Standard_B2s'

@description('MySQL server tier')
param skuTier string = 'Burstable'

@description('Storage size in GB')
param storageSizeGB int = 32

@description('Backup retention in days')
param backupRetentionDays int = 7

@description('Enable geo-redundant backup')
param geoRedundantBackup string = 'Disabled'

@description('Environment name (dev, staging, prod)')
param environment string

@description('Project name for resource naming')
param projectName string

@description('Virtual network ID')
param vnetId string

@description('Database subnet ID')
param subnetId string

@description('Enable high availability')
param enableHighAvailability bool = false

// Variables
var databaseName = 'wordpress'
var commonTags = {
  Project: projectName
  Environment: environment
  ManagedBy: 'Bicep'
  CreatedDate: utcNow('yyyy-MM-dd')
  Service: 'Database'
}

// Generate private DNS zone name
var privateDnsZoneName = '${serverName}.private.mysql.database.azure.com'

// Resources
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: commonTags
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${serverName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2023-06-01-preview' = {
  name: serverName
  location: location
  tags: commonTags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Enabled'
      autoIoScaling: 'Enabled'
      iops: skuTier == 'GeneralPurpose' ? 400 : null
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    network: {
      delegatedSubnetResourceId: subnetId
      privateDnsZoneResourceId: privateDnsZone.id
    }
    highAvailability: enableHighAvailability ? {
      mode: 'SameZone'
    } : null
    version: '8.0'
    createMode: 'Default'
    maintenanceWindow: {
      customWindow: 'Enabled'
      dayOfWeek: 0
      startHour: 2
      startMinute: 0
    }
  }
  dependsOn: [
    privateDnsZoneVnetLink
  ]
}

resource wordpressDatabase 'Microsoft.DBforMySQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: mysqlServer
  name: databaseName
  properties: {
    charset: 'utf8mb4'
    collation: 'utf8mb4_unicode_ci'
  }
}

// MySQL Configuration for WordPress optimization
resource configInnodbBufferPoolSize 'Microsoft.DBforMySQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: mysqlServer
  name: 'innodb_buffer_pool_size'
  properties: {
    value: skuTier == 'GeneralPurpose' ? '1073741824' : '134217728' // 1GB for GP, 128MB for Burstable
    source: 'user-override'
  }
}

resource configMaxConnections 'Microsoft.DBforMySQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: mysqlServer
  name: 'max_connections'
  properties: {
    value: environment == 'prod' ? '500' : '200'
    source: 'user-override'
  }
}

resource configSlowQueryLog 'Microsoft.DBforMySQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: mysqlServer
  name: 'slow_query_log'
  properties: {
    value: 'ON'
    source: 'user-override'
  }
}

resource configLongQueryTime 'Microsoft.DBforMySQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: mysqlServer
  name: 'long_query_time'
  properties: {
    value: environment == 'prod' ? '2' : '1'
    source: 'user-override'
  }
}

resource configMaxAllowedPacket 'Microsoft.DBforMySQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: mysqlServer
  name: 'max_allowed_packet'
  properties: {
    value: '67108864' // 64MB
    source: 'user-override'
  }
}

// Outputs
output serverId string = mysqlServer.id
output serverName string = mysqlServer.name
output serverFQDN string = mysqlServer.properties.fullyQualifiedDomainName
output databaseName string = wordpressDatabase.name
output privateDnsZoneId string = privateDnsZone.id
output administratorLogin string = administratorLogin
EOF
```

### 2.3 Storage Module

```bash
cat > modules/storage/storage.bicep << 'EOF'
@description('Azure Storage Account for WordPress media and backups')

// Parameters
@description('The name of the storage account')
param storageAccountName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('Storage account SKU')
param skuName string = 'Standard_LRS'

@description('Storage account tier')
param accessTier string = 'Hot'

@description('Environment name (dev, staging, prod)')
param environment string

@description('Project name for resource naming')
param projectName string

@description('Enable hierarchical namespace (Data Lake)')
param enableHierarchicalNamespace bool = false

@description('Enable public blob access')
param allowBlobPublicAccess bool = true

// Variables
var containers = [
  {
    name: 'wordpress-media'
    publicAccess: 'Blob'
  }
  {
    name: 'static-assets'
    publicAccess: 'Blob'
  }
  {
    name: 'backups'
    publicAccess: 'None'
  }
  {
    name: 'logs'
    publicAccess: 'None'
  }
]

var commonTags = {
  Project: projectName
  Environment: environment
  ManagedBy: 'Bicep'
  CreatedDate: utcNow('yyyy-MM-dd')
  Service: 'Storage'
}

// Resources
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: enableHierarchicalNamespace
    encryption: {
      requireInfrastructureEncryption: environment == 'prod' ? true : false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Blob service configuration
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'HEAD'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 3600
        }
      ]
    }
    deleteRetentionPolicy: {
      enabled: true
      days: environment == 'prod' ? 30 : 7
    }
    versioning: {
      enabled: environment == 'prod' ? true : false
    }
    changeFeed: {
      enabled: environment == 'prod' ? true : false
    }
  }
}

// Create containers
resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for container in containers: {
  parent: blobServices
  name: container.name
  properties: {
    publicAccess: container.publicAccess
    metadata: {
      environment: environment
      project: projectName
      createdBy: 'Bicep'
    }
  }
}]

// Lifecycle management policy
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'DeleteOldMedia'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'wordpress-media/'
              ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: environment == 'prod' ? 365 : 90
                }
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: environment == 'prod' ? 90 : 60
                }
              }
            }
          }
        }
        {
          enabled: true
          name: 'DeleteOldBackups'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'backups/'
              ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: environment == 'prod' ? 90 : 30
                }
                tierToCool: {
                  daysAfterModificationGreaterThan: 7
                }
              }
            }
          }
        }
      ]
    }
  }
}

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output accessKeys object = {
  key1: storageAccount.listKeys().keys[0].value
  key2: storageAccount.listKeys().keys[1].value
}
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
output containers array = [for (container, i) in containers: {
  name: container.name
  url: '${storageAccount.properties.primaryEndpoints.blob}${container.name}'
}]
EOF
```

### 2.4 Compute Module (Container Instances)

```bash
cat > modules/compute/container-instance.bicep << 'EOF'
@description('Azure Container Instance for WordPress')

// Parameters
@description('Container instance name')
param containerName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('Container image')
param containerImage string

@description('CPU cores')
param cpuCores int = 2

@description('Memory in GB')
param memoryInGB int = 4

@description('Environment name (dev, staging, prod)')
param environment string

@description('Project name for resource naming')
param projectName string

@description('Virtual network ID')
param vnetId string

@description('Subnet ID for container')
param subnetId string

@description('Container registry server')
param registryServer string

@description('Container registry username')
param registryUsername string

@description('Container registry password')
@secure()
param registryPassword string

@description('Environment variables for container')
param environmentVariables array = []

@description('Ports to expose')
param ports array = [
  {
    port: 80
    protocol: 'TCP'
  }
]

@description('Restart policy')
param restartPolicy string = 'OnFailure'

@description('DNS name label')
param dnsNameLabel string

// Variables
var commonTags = {
  Project: projectName
  Environment: environment
  ManagedBy: 'Bicep'
  CreatedDate: utcNow('yyyy-MM-dd')
  Service: 'Compute'
}

// Container instance with VNet integration
resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerName
  location: location
  tags: commonTags
  properties: {
    containers: [
      {
        name: 'wordpress'
        properties: {
          image: containerImage
          ports: ports
          environmentVariables: environmentVariables
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGB
            }
          }
          volumeMounts: []
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: restartPolicy
    imageRegistryCredentials: [
      {
        server: registryServer
        username: registryUsername
        password: registryPassword
      }
    ]
    ipAddress: {
      type: 'Public'
      ports: ports
      dnsNameLabel: dnsNameLabel
    }
    subnetIds: [
      {
        id: subnetId
        name: 'default'
      }
    ]
    sku: 'Standard'
    priority: 'Regular'
  }
}

// Outputs
output containerGroupId string = containerInstance.id
output containerGroupName string = containerInstance.name
output ipAddress string = containerInstance.properties.ipAddress.ip
output fqdn string = containerInstance.properties.ipAddress.fqdn
output provisioningState string = containerInstance.properties.provisioningState
EOF
```

### 2.5 Monitoring Module

```bash
cat > modules/monitoring/app-insights.bicep << 'EOF'
@description('Application Insights and Log Analytics for monitoring')

// Parameters
@description('Application Insights name')
param appInsightsName string

@description('Log Analytics workspace name')
param logAnalyticsName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, staging, prod)')
param environment string

@description('Project name for resource naming')
param projectName string

@description('Log retention in days')
param retentionInDays int = 30

@description('Application type')
param applicationType string = 'web'

@description('Sampling percentage')
param samplingPercentage int = 100

// Variables
var commonTags = {
  Project: projectName
  Environment: environment
  ManagedBy: 'Bicep'
  CreatedDate: utcNow('yyyy-MM-dd')
  Service: 'Monitoring'
}

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: environment == 'prod' ? 10 : 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: applicationType
    Request_Source: 'rest'
    RetentionInDays: retentionInDays
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    SamplingPercentage: samplingPercentage
  }
}

// Action Group for alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${projectName}-${environment}'
  location: 'Global'
  tags: commonTags
  properties: {
    groupShortName: '${take(projectName, 6)}${take(environment, 6)}'
    enabled: true
    emailReceivers: [
      {
        name: 'Admin'
        emailAddress: 'admin@yourdomain.com'
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: []
    armRoleReceivers: [
      {
        name: 'Owner'
        roleId: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Alert rules
resource highErrorRateAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'High Error Rate - ${environment}'
  location: 'Global'
  tags: commonTags
  properties: {
    description: 'High error rate detected'
    severity: environment == 'prod' ? 1 : 2
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: environment == 'prod' ? 10 : 20
          name: 'ErrorRate'
          metricNamespace: 'Microsoft.Insights/components'
          metricName: 'exceptions/count'
          dimensions: []
          operator: 'GreaterThan'
          timeAggregation: 'Total'
          skipMetricValidation: false
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: false
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

resource highResponseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'High Response Time - ${environment}'
  location: 'Global'
  tags: commonTags
  properties: {
    description: 'High response time detected'
    severity: 2
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: environment == 'prod' ? 5000 : 10000
          name: 'ResponseTime'
          metricNamespace: 'Microsoft.Insights/components'
          metricName: 'requests/duration'
          dimensions: []
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          skipMetricValidation: false
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: false
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

// Outputs
output logAnalyticsId string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name
output logAnalyticsWorkspaceId string = logAnalytics.properties.customerId
output logAnalyticsKey string = logAnalytics.listKeys().primarySharedKey
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output appInsightsKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output actionGroupId string = actionGroup.id
EOF
```

## Step 3: Main Template

### 3.1 Create Main Bicep Template

```bash
cat > main/main.bicep << 'EOF'
@description('Main template for WordPress + Next.js infrastructure deployment')

// Parameters
@description('Project name for resource naming')
param projectName string

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

@description('The location for all resources')
param location string = resourceGroup().location

@description('MySQL administrator username')
param mysqlAdminUsername string

@description('MySQL administrator password')
@secure()
param mysqlAdminPassword string

@description('Container registry server')
param containerRegistryServer string

@description('Container registry username')
param containerRegistryUsername string

@description('Container registry password')
@secure()
param containerRegistryPassword string

@description('WordPress container image')
param wordpressImage string = 'wordpress:latest'

@description('Enable high availability (production only)')
param enableHighAvailability bool = false

@description('Enable advanced monitoring')
param enableAdvancedMonitoring bool = true

// Variables
var resourcePrefix = '${projectName}-${environment}'
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)

// Environment-specific configurations
var environmentConfig = {
  dev: {
    mysqlSku: 'Standard_B1s'
    mysqlTier: 'Burstable'
    mysqlStorageGB: 20
    mysqlBackupRetention: 7
    mysqlGeoRedundant: 'Disabled'
    containerCpu: 1
    containerMemory: 2
    storageSku: 'Standard_LRS'
    logRetention: 30
    enableHA: false
  }
  staging: {
    mysqlSku: 'Standard_B2s'
    mysqlTier: 'Burstable'
    mysqlStorageGB: 32
    mysqlBackupRetention: 7
    mysqlGeoRedundant: 'Disabled'
    containerCpu: 1
    containerMemory: 2
    storageSku: 'Standard_LRS'
    logRetention: 30
    enableHA: false
  }
  prod: {
    mysqlSku: 'Standard_D2s_v3'
    mysqlTier: 'GeneralPurpose'
    mysqlStorageGB: 128
    mysqlBackupRetention: 35
    mysqlGeoRedundant: 'Enabled'
    containerCpu: 2
    containerMemory: 4
    storageSku: 'Standard_GRS'
    logRetention: 90
    enableHA: enableHighAvailability
  }
}

var currentConfig = environmentConfig[environment]

// Resource names
var vnetName = 'vnet-${resourcePrefix}'
var mysqlServerName = 'mysql-${resourcePrefix}-${uniqueSuffix}'
var storageAccountName = replace('st${resourcePrefix}${uniqueSuffix}', '-', '')
var containerInstanceName = 'ci-${resourcePrefix}'
var appInsightsName = 'appi-${resourcePrefix}'
var logAnalyticsName = 'log-${resourcePrefix}'
var keyVaultName = 'kv-${resourcePrefix}-${uniqueSuffix}'

// Module: Virtual Network
module vnet 'modules/networking/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    vnetName: vnetName
    location: location
    environment: environment
    projectName: projectName
  }
}

// Module: MySQL Database
module mysql 'modules/database/mysql.bicep' = {
  name: 'mysql-deployment'
  params: {
    serverName: mysqlServerName
    location: location
    administratorLogin: mysqlAdminUsername
    administratorLoginPassword: mysqlAdminPassword
    skuName: currentConfig.mysqlSku
    skuTier: currentConfig.mysqlTier
    storageSizeGB: currentConfig.mysqlStorageGB
    backupRetentionDays: currentConfig.mysqlBackupRetention
    geoRedundantBackup: currentConfig.mysqlGeoRedundant
    environment: environment
    projectName: projectName
    vnetId: vnet.outputs.vnetId
    subnetId: vnet.outputs.subnetIds.database
    enableHighAvailability: currentConfig.enableHA
  }
  dependsOn: [
    vnet
  ]
}

// Module: Storage Account
module storage 'modules/storage/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    skuName: currentConfig.storageSku
    environment: environment
    projectName: projectName
  }
}

// Module: Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: environment == 'prod' ? true : null
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  tags: {
    Project: projectName
    Environment: environment
    ManagedBy: 'Bicep'
  }
}

// Store secrets in Key Vault
resource secretMysqlUsername 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'mysql-admin-username'
  properties: {
    value: mysqlAdminUsername
    contentType: 'text/plain'
  }
}

resource secretMysqlPassword 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'mysql-admin-password'
  properties: {
    value: mysqlAdminPassword
    contentType: 'text/plain'
  }
}

resource secretStorageConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'storage-connection-string'
  properties: {
    value: storage.outputs.connectionString
    contentType: 'text/plain'
  }
}

// Module: Application Insights
module monitoring 'modules/monitoring/app-insights.bicep' = if (enableAdvancedMonitoring) {
  name: 'monitoring-deployment'
  params: {
    appInsightsName: appInsightsName
    logAnalyticsName: logAnalyticsName
    location: location
    environment: environment
    projectName: projectName
    retentionInDays: currentConfig.logRetention
  }
}

// Module: Container Instance
module containerInstance 'modules/compute/container-instance.bicep' = {
  name: 'container-deployment'
  params: {
    containerName: containerInstanceName
    location: location
    containerImage: wordpressImage
    cpuCores: currentConfig.containerCpu
    memoryInGB: currentConfig.containerMemory
    environment: environment
    projectName: projectName
    vnetId: vnet.outputs.vnetId
    subnetId: vnet.outputs.subnetIds.wordpress
    registryServer: containerRegistryServer
    registryUsername: containerRegistryUsername
    registryPassword: containerRegistryPassword
    dnsNameLabel: 'wordpress-${resourcePrefix}-${uniqueSuffix}'
    environmentVariables: [
      {
        name: 'WORDPRESS_DB_HOST'
        value: mysql.outputs.serverFQDN
      }
      {
        name: 'WORDPRESS_DB_NAME'
        value: mysql.outputs.databaseName
      }
      {
        name: 'WORDPRESS_DB_USER'
        value: mysqlAdminUsername
      }
      {
        name: 'WORDPRESS_DB_PASSWORD'
        secureValue: mysqlAdminPassword
      }
      {
        name: 'WORDPRESS_ENV'
        value: environment
      }
      {
        name: 'WP_DEBUG'
        value: environment == 'prod' ? 'false' : 'true'
      }
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storage.outputs.storageAccountName
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: storage.outputs.accessKeys.key1
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: enableAdvancedMonitoring ? monitoring.outputs.appInsightsConnectionString : ''
      }
    ]
  }
  dependsOn: [
    mysql
    storage
    monitoring
  ]
}

// Outputs
output resourceGroupName string = resourceGroup().name
output vnetId string = vnet.outputs.vnetId
output mysqlServerId string = mysql.outputs.serverId
output mysqlServerFQDN string = mysql.outputs.serverFQDN
output storageAccountName string = storage.outputs.storageAccountName
output storageAccountId string = storage.outputs.storageAccountId
output containerInstanceFQDN string = containerInstance.outputs.fqdn
output containerInstanceIP string = containerInstance.outputs.ipAddress
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output appInsightsKey string = enableAdvancedMonitoring ? monitoring.outputs.appInsightsKey : ''
output appInsightsConnectionString string = enableAdvancedMonitoring ? monitoring.outputs.appInsightsConnectionString : ''

// Summary output
output deploymentSummary object = {
  projectName: projectName
  environment: environment
  location: location
  resources: {
    vnet: vnet.outputs.vnetName
    mysql: mysql.outputs.serverName
    storage: storage.outputs.storageAccountName
    container: containerInstance.outputs.containerGroupName
    keyVault: keyVault.name
    monitoring: enableAdvancedMonitoring ? monitoring.outputs.appInsightsName : 'disabled'
  }
  endpoints: {
    wordpress: 'http://${containerInstance.outputs.fqdn}'
    database: mysql.outputs.serverFQDN
    storage: storage.outputs.primaryEndpoints.blob
  }
}
EOF
```

## Step 4: Parameter Files

### 4.1 Production Parameters

```bash
cat > parameters/production/main.parameters.json << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "projectName": {
      "value": "wordpress-nextjs"
    },
    "environment": {
      "value": "prod"
    },
    "location": {
      "value": "East US"
    },
    "mysqlAdminUsername": {
      "value": "wpadmin"
    },
    "mysqlAdminPassword": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}"
        },
        "secretName": "mysql-admin-password"
      }
    },
    "containerRegistryServer": {
      "value": "{acr-name}.azurecr.io"
    },
    "containerRegistryUsername": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}"
        },
        "secretName": "acr-username"
      }
    },
    "containerRegistryPassword": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}"
        },
        "secretName": "acr-password"
      }
    },
    "wordpressImage": {
      "value": "{acr-name}.azurecr.io/wordpress-headless:latest"
    },
    "enableHighAvailability": {
      "value": true
    },
    "enableAdvancedMonitoring": {
      "value": true
    }
  }
}
EOF
```

### 4.2 Staging Parameters

```bash
cat > parameters/staging/main.parameters.json << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "projectName": {
      "value": "wordpress-nextjs"
    },
    "environment": {
      "value": "staging"
    },
    "location": {
      "value": "East US"
    },
    "mysqlAdminUsername": {
      "value": "wpadmin"
    },
    "mysqlAdminPassword": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}"
        },
        "secretName": "mysql-admin-password-staging"
      }
    },
    "containerRegistryServer": {
      "value": "{acr-name}.azurecr.io"
    },
    "containerRegistryUsername": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}"
        },
        "secretName": "acr-username"
      }
    },
    "containerRegistryPassword": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}"
        },
        "secretName": "acr-password"
      }
    },
    "wordpressImage": {
      "value": "{acr-name}.azurecr.io/wordpress-headless:develop"
    },
    "enableHighAvailability": {
      "value": false
    },
    "enableAdvancedMonitoring": {
      "value": true
    }
  }
}
EOF
```

### 4.3 Development Parameters

```bash
cat > parameters/development/main.parameters.json << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "projectName": {
      "value": "wordpress-nextjs"
    },
    "environment": {
      "value": "dev"
    },
    "location": {
      "value": "East US"
    },
    "mysqlAdminUsername": {
      "value": "wpadmin"
    },
    "mysqlAdminPassword": {
      "value": "DevPassword123!"
    },
    "containerRegistryServer": {
      "value": "docker.io"
    },
    "containerRegistryUsername": {
      "value": ""
    },
    "containerRegistryPassword": {
      "value": ""
    },
    "wordpressImage": {
      "value": "wordpress:latest"
    },
    "enableHighAvailability": {
      "value": false
    },
    "enableAdvancedMonitoring": {
      "value": false
    }
  }
}
EOF
```

## Step 5: Deployment Scripts

### 5.1 Deployment Script

```bash
cat > scripts/deploy/deploy.ps1 << 'EOF'
#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploy WordPress + Next.js infrastructure using Bicep

.DESCRIPTION
    This script deploys the complete infrastructure for the WordPress + Next.js solution
    using Azure Bicep templates.

.PARAMETER Environment
    The target environment (dev, staging, prod)

.PARAMETER Location
    Azure region for deployment

.PARAMETER ResourceGroupName
    Name of the resource group

.PARAMETER SubscriptionId
    Azure subscription ID

.PARAMETER ParametersFile
    Path to parameters file (optional)

.PARAMETER WhatIf
    Preview changes without deploying

.EXAMPLE
    ./deploy.ps1 -Environment prod -ResourceGroupName "rg-wordpress-prod" -Location "East US"

.EXAMPLE
    ./deploy.ps1 -Environment staging -ResourceGroupName "rg-wordpress-staging" -WhatIf
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Validate
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$BicepRoot = Join-Path $ProjectRoot "infrastructure/bicep"
$MainTemplate = Join-Path $BicepRoot "main/main.bicep"

# Default parameters file if not specified
if (-not $ParametersFile) {
    $ParametersFile = Join-Path $BicepRoot "parameters/$Environment/main.parameters.json"
}

# Validate files exist
if (-not (Test-Path $MainTemplate)) {
    throw "Main template not found: $MainTemplate"
}

if (-not (Test-Path $ParametersFile)) {
    throw "Parameters file not found: $ParametersFile"
}

Write-Host "Starting deployment..." -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Template: $MainTemplate" -ForegroundColor Yellow
Write-Host "Parameters: $ParametersFile" -ForegroundColor Yellow

try {
    # Set subscription if provided
    if ($SubscriptionId) {
        Write-Host "Setting subscription: $SubscriptionId" -ForegroundColor Blue
        az account set --subscription $SubscriptionId
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set subscription"
        }
    }
    
    # Verify login
    Write-Host "Verifying Azure login..." -ForegroundColor Blue
    $account = az account show --output json | ConvertFrom-Json
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
    
    # Create resource group if it doesn't exist
    Write-Host "Ensuring resource group exists..." -ForegroundColor Blue
    $rgExists = az group exists --name $ResourceGroupName
    
    if ($rgExists -eq "false") {
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location --tags "Project=wordpress-nextjs" "Environment=$Environment" "ManagedBy=Bicep"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create resource group"
        }
    } else {
        Write-Host "Resource group already exists: $ResourceGroupName" -ForegroundColor Green
    }
    
    # Build Bicep template
    Write-Host "Building Bicep template..." -ForegroundColor Blue
    az bicep build --file $MainTemplate
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build Bicep template"
    }
    
    # Validate template
    if ($Validate -or $WhatIf) {
        Write-Host "Validating deployment..." -ForegroundColor Blue
        az deployment group validate `
            --resource-group $ResourceGroupName `
            --template-file $MainTemplate `
            --parameters $ParametersFile
        
        if ($LASTEXITCODE -ne 0) {
            throw "Template validation failed"
        }
        
        Write-Host "Template validation successful!" -ForegroundColor Green
    }
    
    # What-if deployment
    if ($WhatIf) {
        Write-Host "Running What-If deployment..." -ForegroundColor Blue
        az deployment group what-if `
            --resource-group $ResourceGroupName `
            --template-file $MainTemplate `
            --parameters $ParametersFile
        
        Write-Host "What-If deployment completed" -ForegroundColor Green
        return
    }
    
    # Deploy template
    Write-Host "Starting deployment..." -ForegroundColor Blue
    $deploymentName = "wordpress-nextjs-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    az deployment group create `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --template-file $MainTemplate `
        --parameters $ParametersFile `
        --verbose
    
    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed"
    }
    
    # Get deployment outputs
    Write-Host "Retrieving deployment outputs..." -ForegroundColor Blue
    $outputs = az deployment group show `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --query properties.outputs `
        --output json | ConvertFrom-Json
    
    # Display summary
    Write-Host "`n=== Deployment Summary ===" -ForegroundColor Green
    Write-Host "Deployment Name: $deploymentName" -ForegroundColor White
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "Environment: $Environment" -ForegroundColor White
    
    if ($outputs.deploymentSummary) {
        $summary = $outputs.deploymentSummary.value
        Write-Host "`nResources Created:" -ForegroundColor Yellow
        $summary.resources.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
        }
        
        Write-Host "`nEndpoints:" -ForegroundColor Yellow
        $summary.endpoints.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
        }
    }
    
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}
EOF

chmod +x scripts/deploy/deploy.ps1
```

### 5.2 Bash Deployment Script

```bash
cat > scripts/deploy/deploy.sh << 'EOF'
#!/bin/bash

# WordPress + Next.js Infrastructure Deployment Script
# This script deploys the complete infrastructure using Bicep templates

set -e

# Default values
ENVIRONMENT=""
RESOURCE_GROUP=""
LOCATION=""
SUBSCRIPTION_ID=""
PARAMETERS_FILE=""
WHAT_IF=false
VALIDATE_ONLY=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_usage() {
    echo "Usage: $0 -e <environment> -g <resource-group> -l <location> [options]"
    echo ""
    echo "Required options:"
    echo "  -e, --environment      Environment (dev, staging, prod)"
    echo "  -g, --resource-group   Resource group name"
    echo "  -l, --location         Azure region"
    echo ""
    echo "Optional options:"
    echo "  -s, --subscription     Azure subscription ID"
    echo "  -p, --parameters       Parameters file path"
    echo "  -w, --what-if          Preview changes without deploying"
    echo "  -v, --validate         Validate template only"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e prod -g rg-wordpress-prod -l 'East US'"
    echo "  $0 -e staging -g rg-wordpress-staging -l 'East US' --what-if"
}

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -p|--parameters)
            PARAMETERS_FILE="$2"
            shift 2
            ;;
        -w|--what-if)
            WHAT_IF=true
            shift
            ;;
        -v|--validate)
            VALIDATE_ONLY=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$ENVIRONMENT" || -z "$RESOURCE_GROUP" || -z "$LOCATION" ]]; then
    error "Missing required parameters"
    print_usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    error "Invalid environment. Must be dev, staging, or prod"
    exit 1
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")" 
BICEP_ROOT="$PROJECT_ROOT/infrastructure/bicep"
MAIN_TEMPLATE="$BICEP_ROOT/main/main.bicep"

# Default parameters file if not specified
if [[ -z "$PARAMETERS_FILE" ]]; then
    PARAMETERS_FILE="$BICEP_ROOT/parameters/$ENVIRONMENT/main.parameters.json"
fi

# Validate files exist
if [[ ! -f "$MAIN_TEMPLATE" ]]; then
    error "Main template not found: $MAIN_TEMPLATE"
    exit 1
fi

if [[ ! -f "$PARAMETERS_FILE" ]]; then
    error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi

# Start deployment
log "Starting deployment..."
debug "Environment: $ENVIRONMENT"
debug "Resource Group: $RESOURCE_GROUP"
debug "Location: $LOCATION"
debug "Template: $MAIN_TEMPLATE"
debug "Parameters: $PARAMETERS_FILE"

# Set subscription if provided
if [[ -n "$SUBSCRIPTION_ID" ]]; then
    log "Setting subscription: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

# Verify login
log "Verifying Azure login..."
ACCOUNT_INFO=$(az account show --output json)
USER_NAME=$(echo "$ACCOUNT_INFO" | jq -r '.user.name')
SUBSCRIPTION_NAME=$(echo "$ACCOUNT_INFO" | jq -r '.name')
SUBSCRIPTION_ID_CURRENT=$(echo "$ACCOUNT_INFO" | jq -r '.id')

log "Logged in as: $USER_NAME"
log "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID_CURRENT)"

# Create resource group if it doesn't exist
log "Ensuring resource group exists..."
if ! az group exists --name "$RESOURCE_GROUP" --output tsv | grep -q "true"; then
    log "Creating resource group: $RESOURCE_GROUP"
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Project=wordpress-nextjs" "Environment=$ENVIRONMENT" "ManagedBy=Bicep"
else
    log "Resource group already exists: $RESOURCE_GROUP"
fi

# Build Bicep template
log "Building Bicep template..."
az bicep build --file "$MAIN_TEMPLATE"

# Validate template
if [[ "$VALIDATE_ONLY" == true ]] || [[ "$WHAT_IF" == true ]]; then
    log "Validating deployment..."
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$MAIN_TEMPLATE" \
        --parameters "$PARAMETERS_FILE"
    
    log "Template validation successful!"
fi

# What-if deployment
if [[ "$WHAT_IF" == true ]]; then
    log "Running What-If deployment..."
    az deployment group what-if \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$MAIN_TEMPLATE" \
        --parameters "$PARAMETERS_FILE"
    
    log "What-If deployment completed"
    exit 0
fi

# Exit if validate only
if [[ "$VALIDATE_ONLY" == true ]]; then
    log "Validation completed"
    exit 0
fi

# Deploy template
log "Starting deployment..."
DEPLOYMENT_NAME="wordpress-nextjs-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$MAIN_TEMPLATE" \
    --parameters "$PARAMETERS_FILE" \
    --verbose

# Get deployment outputs
log "Retrieving deployment outputs..."
OUTPUTS=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs \
    --output json)

# Display summary
echo ""
log "=== Deployment Summary ==="
log "Deployment Name: $DEPLOYMENT_NAME"
log "Resource Group: $RESOURCE_GROUP"
log "Environment: $ENVIRONMENT"

if echo "$OUTPUTS" | jq -e '.deploymentSummary' > /dev/null; then
    SUMMARY=$(echo "$OUTPUTS" | jq -r '.deploymentSummary.value')
    
    echo ""
    warn "Resources Created:"
    echo "$SUMMARY" | jq -r '.resources | to_entries[] | "  \(.key): \(.value)"'
    
    echo ""
    warn "Endpoints:"
    echo "$SUMMARY" | jq -r '.endpoints | to_entries[] | "  \(.key): \(.value)"'
fi

echo ""
log "Deployment completed successfully!"
EOF

chmod +x scripts/deploy/deploy.sh
```

### 5.3 Validation Script

```bash
cat > scripts/validate/validate.sh << 'EOF'
#!/bin/bash

# Bicep Template Validation Script
# This script validates all Bicep templates and parameter files

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")" 
BICEP_ROOT="$PROJECT_ROOT/infrastructure/bicep"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Validation functions
validate_bicep_files() {
    log "Validating Bicep template syntax..."
    
    local error_count=0
    
    # Find all .bicep files
    while IFS= read -r -d '' file; do
        log "Validating: $file"
        
        if ! az bicep build --file "$file" --stdout > /dev/null; then
            error "Syntax error in: $file"
            ((error_count++))
        fi
    done < <(find "$BICEP_ROOT" -name "*.bicep" -print0)
    
    if [[ $error_count -eq 0 ]]; then
        log "All Bicep files validated successfully"
    else
        error "Found $error_count Bicep files with syntax errors"
        return 1
    fi
}

validate_parameter_files() {
    log "Validating parameter files..."
    
    local error_count=0
    
    # Find all .json parameter files
    while IFS= read -r -d '' file; do
        log "Validating JSON: $file"
        
        if ! jq empty < "$file" 2>/dev/null; then
            error "Invalid JSON in: $file"
            ((error_count++))
        fi
    done < <(find "$BICEP_ROOT/parameters" -name "*.json" -print0)
    
    if [[ $error_count -eq 0 ]]; then
        log "All parameter files validated successfully"
    else
        error "Found $error_count parameter files with JSON errors"
        return 1
    fi
}

validate_deployments() {
    log "Validating deployment templates..."
    
    local environments=("dev" "staging" "prod")
    local error_count=0
    
    for env in "${environments[@]}"; do
        log "Validating $env environment..."
        
        local template="$BICEP_ROOT/main/main.bicep"
        local parameters="$BICEP_ROOT/parameters/$env/main.parameters.json"
        
        if [[ ! -f "$template" ]]; then
            error "Main template not found: $template"
            ((error_count++))
            continue
        fi
        
        if [[ ! -f "$parameters" ]]; then
            warn "Parameters file not found: $parameters (skipping)"
            continue
        fi
        
        # Create a temporary resource group for validation
        local temp_rg="rg-bicep-validation-$(date +%s)"
        
        log "Creating temporary resource group for validation: $temp_rg"
        if az group create --name "$temp_rg" --location "East US" --tags "Purpose=Validation" "AutoDelete=true" > /dev/null; then
            
            # Validate deployment
            if az deployment group validate \
                --resource-group "$temp_rg" \
                --template-file "$template" \
                --parameters "$parameters" > /dev/null; then
                log "$env environment validation successful"
            else
                error "$env environment validation failed"
                ((error_count++))
            fi
            
            # Clean up temporary resource group
            log "Cleaning up temporary resource group: $temp_rg"
            az group delete --name "$temp_rg" --yes --no-wait > /dev/null
        else
            error "Failed to create temporary resource group for validation"
            ((error_count++))
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        log "All deployment validations successful"
    else
        error "Found $error_count deployment validation errors"
        return 1
    fi
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        error "Azure CLI is not installed"
        return 1
    fi
    
    # Check Bicep CLI
    if ! az bicep version &> /dev/null; then
        error "Bicep CLI is not installed"
        return 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        error "jq is not installed"
        return 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        error "Not logged into Azure. Run 'az login' first."
        return 1
    fi
    
    log "Prerequisites check passed"
}

generate_report() {
    log "Generating validation report..."
    
    local report_file="bicep-validation-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOL
# Bicep Template Validation Report

Generated: $(date)

## Summary

- **Bicep Templates**: $(find "$BICEP_ROOT" -name "*.bicep" | wc -l) files validated
- **Parameter Files**: $(find "$BICEP_ROOT/parameters" -name "*.json" | wc -l) files validated
- **Environments**: 3 environments tested (dev, staging, prod)

## Bicep Files

$(find "$BICEP_ROOT" -name "*.bicep" | while read -r file; do
    echo "- ${file#$BICEP_ROOT/}"
done)

## Parameter Files

$(find "$BICEP_ROOT/parameters" -name "*.json" | while read -r file; do
    echo "- ${file#$BICEP_ROOT/}"
done)

## Validation Results

✅ All validations passed successfully

EOL

    log "Validation report generated: $report_file"
}

# Main execution
main() {
    log "Starting Bicep template validation..."
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Run validations
    local validation_errors=0
    
    if ! validate_bicep_files; then
        ((validation_errors++))
    fi
    
    if ! validate_parameter_files; then
        ((validation_errors++))
    fi
    
    if ! validate_deployments; then
        ((validation_errors++))
    fi
    
    # Summary
    if [[ $validation_errors -eq 0 ]]; then
        log "All validations passed successfully! 🎉"
        generate_report
        exit 0
    else
        error "Validation failed with $validation_errors error(s)"
        exit 1
    fi
}

# Run main function
main "$@"
EOF

chmod +x scripts/validate/validate.sh
```

## Step 6: CI/CD Integration

### 6.1 GitHub Actions Bicep Deployment

```bash
cat > ../../.github/workflows/bicep-deploy.yml << 'EOF'
name: Bicep Infrastructure Deployment

on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'infrastructure/bicep/**'
  pull_request:
    branches:
      - main
    paths:
      - 'infrastructure/bicep/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options:
        - dev
        - staging
        - prod
      whatif:
        description: 'Run What-If (preview changes)'
        required: false
        default: false
        type: boolean

env:
  AZURE_LOCATION: 'East US'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Install Bicep CLI
        run: |
          az bicep install
          az bicep version

      - name: Validate Bicep templates
        run: |
          chmod +x infrastructure/bicep/scripts/validate/validate.sh
          ./infrastructure/bicep/scripts/validate/validate.sh

  deploy-dev:
    runs-on: ubuntu-latest
    needs: validate
    if: github.ref == 'refs/heads/develop' || (github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'dev')
    environment: development
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy to Development
        run: |
          chmod +x infrastructure/bicep/scripts/deploy/deploy.sh
          ./infrastructure/bicep/scripts/deploy/deploy.sh \
            -e dev \
            -g "rg-wordpress-nextjs-dev" \
            -l "$AZURE_LOCATION" \
            -s "${{ secrets.AZURE_SUBSCRIPTION_ID }}"

  deploy-staging:
    runs-on: ubuntu-latest
    needs: validate
    if: github.ref == 'refs/heads/develop' || (github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'staging')
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy to Staging
        run: |
          chmod +x infrastructure/bicep/scripts/deploy/deploy.sh
          
          if [[ "${{ github.event.inputs.whatif }}" == "true" ]]; then
            WHAT_IF_FLAG="--what-if"
          else
            WHAT_IF_FLAG=""
          fi
          
          ./infrastructure/bicep/scripts/deploy/deploy.sh \
            -e staging \
            -g "rg-wordpress-nextjs-staging" \
            -l "$AZURE_LOCATION" \
            -s "${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
            $WHAT_IF_FLAG

  deploy-prod:
    runs-on: ubuntu-latest
    needs: validate
    if: github.ref == 'refs/heads/main' || (github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'prod')
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy to Production
        run: |
          chmod +x infrastructure/bicep/scripts/deploy/deploy.sh
          
          if [[ "${{ github.event.inputs.whatif }}" == "true" ]]; then
            WHAT_IF_FLAG="--what-if"
          else
            WHAT_IF_FLAG=""
          fi
          
          ./infrastructure/bicep/scripts/deploy/deploy.sh \
            -e prod \
            -g "rg-wordpress-nextjs-prod" \
            -l "$AZURE_LOCATION" \
            -s "${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
            $WHAT_IF_FLAG

      - name: Post-deployment validation
        run: |
          # Add post-deployment tests here
          echo "Running post-deployment validation..."
          # Example: Test endpoints, verify resources, etc.

  notify:
    runs-on: ubuntu-latest
    needs: [deploy-dev, deploy-staging, deploy-prod]
    if: always()
    steps:
      - name: Send notification
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#infrastructure'
          text: |
            Bicep infrastructure deployment completed
            
            Environment: ${{ github.event.inputs.environment || 'auto' }}
            Branch: ${{ github.ref_name }}
            Commit: ${{ github.sha }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
EOF
```

## Step 7: Documentation and Best Practices

### 7.1 Create Bicep Best Practices Guide

```bash
cat > bicep-best-practices.md << 'EOF'
# Bicep Best Practices for WordPress + Next.js Infrastructure

## Template Organization

### Module Structure
- **Single responsibility**: Each module should handle one logical component
- **Reusability**: Modules should be parameterized for different environments
- **Composability**: Modules should work well together

### Naming Conventions
- **Resources**: Use descriptive names with environment suffixes
- **Parameters**: Use camelCase with clear descriptions
- **Variables**: Use camelCase and group related variables
- **Outputs**: Use camelCase with descriptive names

### Parameter Guidelines
- **Required parameters**: Only make parameters required if they must be specified
- **Default values**: Provide sensible defaults where possible
- **Parameter descriptions**: Always include @description decorators
- **Parameter validation**: Use @allowed, @minLength, @maxLength where appropriate

## Security Best Practices

### Secrets Management
- **Never hardcode secrets**: Use Key Vault references for sensitive data
- **Secure parameters**: Use @secure() decorator for passwords and keys
- **Minimal permissions**: Grant only necessary permissions to resources

### Network Security
- **Private endpoints**: Use private endpoints for database and storage
- **Network security groups**: Implement restrictive NSG rules
- **DDoS protection**: Enable for production environments

### Resource Security
- **Managed identities**: Use managed identities instead of service principals
- **RBAC**: Implement role-based access control
- **Encryption**: Enable encryption at rest and in transit

## Performance and Cost Optimization

### Resource Sizing
- **Environment-appropriate sizing**: Use smaller SKUs for dev/staging
- **Auto-scaling**: Implement auto-scaling where supported
- **Reserved instances**: Consider reserved instances for production

### Cost Management
- **Resource tagging**: Tag all resources for cost allocation
- **Lifecycle policies**: Implement storage lifecycle policies
- **Budget alerts**: Set up cost monitoring and alerts

## Deployment Best Practices

### Environment Management
- **Parameter files**: Use separate parameter files for each environment
- **Environment validation**: Test deployments in non-production first
- **Blue-green deployments**: Consider blue-green deployment patterns

### Change Management
- **Infrastructure as Code**: All changes should go through version control
- **Code reviews**: Require reviews for infrastructure changes
- **Automated testing**: Validate templates before deployment

### Monitoring and Observability
- **Resource monitoring**: Enable monitoring for all critical resources
- **Alerting**: Set up alerts for failures and performance issues
- **Logging**: Centralize logs using Log Analytics

## Template Quality

### Code Quality
- **Consistent formatting**: Use consistent indentation and formatting
- **Comments**: Add comments for complex logic
- **Error handling**: Handle potential errors gracefully

### Testing
- **Syntax validation**: Always validate Bicep syntax
- **Deployment testing**: Test deployments in safe environments
- **What-if analysis**: Use what-if to preview changes

### Documentation
- **README files**: Provide clear documentation for each module
- **Parameter documentation**: Document all parameters and their purposes
- **Architecture diagrams**: Include architecture diagrams

## Common Patterns

### Conditional Resources
```bicep
resource highAvailabilityFeature 'Microsoft.Example/resource@2023-01-01' = if (environment == 'prod') {
  // Resource definition
}
```

### Resource Dependencies
```bicep
resource dependent 'Microsoft.Example/dependent@2023-01-01' = {
  // Resource definition
  dependsOn: [
    prerequisite
  ]
}
```

### Output Chaining
```bicep
output resourceId string = resource.id
output resourceName string = resource.name
```

### Environment-Specific Configuration
```bicep
var environmentConfig = {
  dev: {
    sku: 'Basic'
    replicas: 1
  }
  prod: {
    sku: 'Premium'
    replicas: 3
  }
}

var currentConfig = environmentConfig[environment]
```

## Troubleshooting

### Common Issues

1. **Resource naming conflicts**: Use unique suffixes
2. **Circular dependencies**: Carefully plan resource dependencies  
3. **Parameter validation errors**: Check parameter constraints
4. **Permission issues**: Verify service principal permissions

### Debugging Tips

1. **Use what-if**: Preview changes before deployment
2. **Check activity logs**: Review Azure activity logs for errors
3. **Validate syntax**: Use `az bicep build` to check syntax
4. **Test incrementally**: Deploy modules individually for testing

## Resources

- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Bicep Best Practices](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/best-practices)
- [Azure Architecture Center](https://docs.microsoft.com/en-us/azure/architecture/)
EOF
```

### 7.2 Final Summary and Checklist

```bash
# Update .env.azure with Bicep configuration
cat >> .env.azure << 'EOF'

# Infrastructure as Code (Bicep)
BICEP_ENABLED=true
BICEP_MAIN_TEMPLATE=infrastructure/bicep/main/main.bicep
BICEP_MODULES_PATH=infrastructure/bicep/modules
BICEP_PARAMETERS_PATH=infrastructure/bicep/parameters
BICEP_VALIDATION_ENABLED=true
BICEP_DEPLOYMENT_MODE=Incremental

# Deployment Settings
DEPLOYMENT_TIMEOUT_MINUTES=60
DEPLOYMENT_RETRY_COUNT=3
DEPLOYMENT_PARALLEL_ENABLED=true
WHAT_IF_ENABLED=true

# Template Validation
SYNTAX_VALIDATION=true
PARAMETER_VALIDATION=true
DEPLOYMENT_VALIDATION=true
SECURITY_VALIDATION=true

# Resource Naming
RESOURCE_PREFIX=wordpress-nextjs
RESOURCE_SUFFIX_ENABLED=true
UNIQUE_STRING_LENGTH=6
TAGGING_STRATEGY=comprehensive
EOF

echo "Bicep Infrastructure as Code setup completed!"
echo "Configuration saved to .env.azure"
```

### 7.3 Create Bicep Setup Checklist

```bash
cat > bicep-setup-checklist.md << 'EOF'
# Bicep Infrastructure Setup Checklist

## Project Structure
- [ ] Bicep directory structure created
- [ ] Main templates organized in main/ directory
- [ ] Modules organized by service type
- [ ] Parameter files for each environment
- [ ] Deployment and validation scripts created

## Module Development
- [ ] Networking module (VNet, subnets, NSGs)
- [ ] Database module (MySQL Flexible Server)
- [ ] Storage module (Storage Account with containers)
- [ ] Compute module (Container Instances)
- [ ] Monitoring module (App Insights, Log Analytics)
- [ ] Security module (Key Vault)

## Template Validation
- [ ] Syntax validation passing for all templates
- [ ] Parameter file validation passing
- [ ] Deployment validation tested for all environments
- [ ] What-if analysis tested
- [ ] Security best practices implemented

## Environment Configuration
- [ ] Development parameter file configured
- [ ] Staging parameter file configured  
- [ ] Production parameter file configured
- [ ] Key Vault references properly configured
- [ ] Environment-specific sizing implemented

## Deployment Automation
- [ ] PowerShell deployment script functional
- [ ] Bash deployment script functional
- [ ] Validation script functional
- [ ] GitHub Actions workflow configured
- [ ] CI/CD integration tested

## Security Implementation
- [ ] Key Vault for secrets management
- [ ] Secure parameters for sensitive data
- [ ] Network security groups configured
- [ ] Private endpoints enabled where appropriate
- [ ] RBAC permissions properly configured

## Monitoring and Observability
- [ ] Application Insights configured
- [ ] Log Analytics workspace configured
- [ ] Alert rules configured
- [ ] Action groups for notifications
- [ ] Custom dashboards configured

## Documentation
- [ ] Best practices guide created
- [ ] Module documentation complete
- [ ] Parameter documentation complete
- [ ] Architecture diagrams updated
- [ ] Troubleshooting guide created

## Testing and Validation
- [ ] Deployment tested in development
- [ ] Deployment tested in staging  
- [ ] What-if analysis verified
- [ ] Resource cleanup tested
- [ ] Rollback procedures tested

## Production Readiness
- [ ] High availability configured
- [ ] Backup and recovery implemented
- [ ] Cost monitoring enabled
- [ ] Security hardening applied
- [ ] Performance optimization implemented
- [ ] Disaster recovery plan tested
EOF
```

## Summary

The Bicep Infrastructure as Code implementation provides:

- **Modular architecture** with reusable components
- **Environment-specific configurations** for dev/staging/production
- **Comprehensive security** with Key Vault and network isolation
- **Automated deployment** with PowerShell and Bash scripts
- **CI/CD integration** with GitHub Actions
- **Validation and testing** capabilities
- **Best practices** implementation throughout
- **Complete documentation** and troubleshooting guides

## Next Steps

1. Continue with [Monitoring Setup](../monitoring/azure-monitor-setup.md)
2. Set up [Disaster Recovery](../backup-dr/disaster-recovery-plan.md)
3. Configure [Cost Optimization](./cost-optimization.md)
4. Implement [Security Hardening](./resource-tagging.md)
5. Review [Terraform Setup](./terraform-setup.md) (alternative)

The Infrastructure as Code foundation is now ready to support reliable, scalable, and maintainable deployments of the WordPress + Next.js solution across all environments.

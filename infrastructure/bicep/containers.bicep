// WordPress backend infrastructure
// Container Apps, MySQL Flexible Server, Redis Cache

@description('Resource name prefix')
param resourceNamePrefix string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Container subnet ID')
param subnetId string

@description('Key Vault name for secrets')
param keyVaultName string

@description('MySQL administrator username')
param mysqlAdminUsername string

@description('MySQL administrator password')
@secure()
param mysqlAdminPassword string


@description('Environment name')
param environment string

// Variables
var containerAppEnvName = '${resourceNamePrefix}-env'
var wordpressAppName = '${resourceNamePrefix}-wordpress'
var mysqlServerName = '${resourceNamePrefix}-mysql'
var redisName = '${resourceNamePrefix}-redis'
var logAnalyticsName = '${resourceNamePrefix}-logs'
var appInsightsName = '${resourceNamePrefix}-ai'

// Reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// MySQL Flexible Server
resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2023-06-30' = {
  name: mysqlServerName
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: mysqlAdminUsername
    administratorLoginPassword: mysqlAdminPassword
    version: '8.0.21'
    storage: {
      storageSizeGB: 20
      iops: 360
      autoGrow: 'Enabled'
      autoIoScaling: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: subnetId
      privateDnsZoneResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/privateDnsZones/${resourceNamePrefix}.mysql.database.azure.com'
    }
    maintenanceWindow: {
      customWindow: 'Enabled'
      dayOfWeek: 0
      startHour: 2
      startMinute: 0
    }
  }
}

// MySQL Database
resource wordpressDatabase 'Microsoft.DBforMySQL/flexibleServers/databases@2023-06-30' = {
  parent: mysqlServer
  name: 'wordpress'
  properties: {
    charset: 'utf8mb4'
    collation: 'utf8mb4_unicode_ci'
  }
}

// MySQL Configuration
resource mysqlConfig 'Microsoft.DBforMySQL/flexibleServers/configurations@2023-06-30' = {
  parent: mysqlServer
  name: 'innodb_buffer_pool_size'
  properties: {
    value: '134217728'
    source: 'user-override'
  }
}

// Redis Cache
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

// Private Endpoint for Redis
resource redisPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = {
  name: '${redisName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${redisName}-pe-connection'
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
}

// Container Apps Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: false
    }
    zoneRedundant: false
  }
}

// WordPress Container App
resource wordpressApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: wordpressAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      secrets: [
        {
          name: 'mysql-password'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/mysql-admin-password'
          identity: 'system'
        }
        {
          name: 'wordpress-db-password'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/wordpress-db-password'
          identity: 'system'
        }
        {
          name: 'redis-password'
          value: redisCache.listKeys().primaryKey
        }
      ]
      registries: [
        {
          server: 'docker.io'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'wordpress'
          image: 'wordpress:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'WORDPRESS_DB_HOST'
              value: '${mysqlServer.properties.fullyQualifiedDomainName}:3306'
            }
            {
              name: 'WORDPRESS_DB_NAME'
              value: 'wordpress'
            }
            {
              name: 'WORDPRESS_DB_USER'
              value: mysqlAdminUsername
            }
            {
              name: 'WORDPRESS_DB_PASSWORD'
              secretRef: 'mysql-password'
            }
            {
              name: 'WORDPRESS_TABLE_PREFIX'
              value: 'wp_'
            }
            {
              name: 'WORDPRESS_CONFIG_EXTRA'
              value: 'define("WP_REDIS_HOST", "${redisCache.properties.hostName}"); define("WP_REDIS_PORT", 6380); define("WP_REDIS_PASSWORD", "${redisCache.listKeys().primaryKey}"); define("WP_REDIS_TIMEOUT", 1); define("WP_REDIS_READ_TIMEOUT", 1); define("WP_REDIS_DATABASE", 0);'
            }
            {
              name: 'WORDPRESS_DEBUG'
              value: environment == 'prod' ? 'false' : 'true'
            }
            {
              name: 'WORDPRESS_DEBUG_LOG'
              value: environment == 'prod' ? 'false' : 'true'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/wp-admin/install.php'
                port: 80
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/wp-admin/install.php'
                port: 80
                scheme: 'HTTP'
              }
              initialDelaySeconds: 5
              periodSeconds: 5
              timeoutSeconds: 3
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: environment == 'prod' ? 10 : 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Key Vault Access Policy for Container App
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: wordpressApp.identity.tenantId
        objectId: wordpressApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

// Auto-scaling rules for production
resource prodScalingRule 'Microsoft.App/containerApps@2023-05-01' = if (environment == 'prod') {
  name: '${wordpressAppName}-scaling'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: wordpressApp.properties.configuration.ingress
      secrets: wordpressApp.properties.configuration.secrets
    }
    template: {
      containers: wordpressApp.properties.template.containers
      scale: {
        minReplicas: 2
        maxReplicas: 20
        rules: [
          {
            name: 'cpu-scaling'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: '70'
              }
            }
          }
          {
            name: 'memory-scaling'
            custom: {
              type: 'memory'
              metadata: {
                type: 'Utilization'
                value: '80'
              }
            }
          }
        ]
      }
    }
  }
}

// Outputs
output wordpressUrl string = 'https://${wordpressApp.properties.configuration.ingress.fqdn}'
output wordpressAppId string = wordpressApp.id
output mysqlServerName string = mysqlServer.properties.fullyQualifiedDomainName
output mysqlServerId string = mysqlServer.id
output redisHostname string = redisCache.properties.hostName
output redisId string = redisCache.id
output containerAppEnvironmentId string = containerAppEnvironment.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output applicationInsightsId string = appInsights.id
output applicationInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString

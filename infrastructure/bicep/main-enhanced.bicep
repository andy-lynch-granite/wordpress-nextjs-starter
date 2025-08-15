// Enhanced main infrastructure template for WordPress + Next.js on Azure
// Implements production-ready configuration with enhanced security, monitoring, and cost optimization
// Updated naming conventions and best practices

@description('Environment name (prod, staging, dev, preview)')
@allowed(['prod', 'staging', 'dev', 'preview'])
param environment string = 'dev'

@description('Project name identifier')
param projectName string = 'wp-nextjs'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Domain name for the website (without protocol)')
param domainName string = 'example.com'

@description('Enable WordPress backend deployment')
param deployWordPressBackend bool = true

@description('Enable monitoring and logging')
param enableMonitoring bool = true

@description('Enable enhanced security features')
param enableEnhancedSecurity bool = true

@description('WordPress admin email')
param wordpressAdminEmail string = 'admin@example.com'

@description('MySQL administrator username')
param mysqlAdminUsername string = 'wpadmin'

@description('Enable multi-region deployment for production')
param enableMultiRegion bool = false

@description('Cost optimization tier (basic, standard, premium)')
@allowed(['basic', 'standard', 'premium'])
param costTier string = 'standard'

@description('Backup retention days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 14

@secure()
@description('MySQL administrator password')
param mysqlAdminPassword string

@secure()
@description('WordPress database password')
param wordpressDbPassword string

// Enhanced Variables with proper naming convention
var regionAbbr = {
  'eastus': 'eus'
  'eastus2': 'eus2'
  'westus2': 'wus2'
  'centralus': 'cus'
  'northeurope': 'neu'
  'westeurope': 'weu'
  'southeastasia': 'sea'
  'australiaeast': 'aue'
}

var currentRegionAbbr = regionAbbr[location]
var resourceNamePrefix = '${projectName}-${environment}'
var resourceNamePrefixWithRegion = '${projectName}-${environment}-${currentRegionAbbr}'

// Enhanced tagging strategy
var commonTags = {
  Environment: environment
  Project: projectName
  ManagedBy: 'bicep'
  Owner: 'platform-team'
  BusinessUnit: 'digital'
  Purpose: 'wordpress-nextjs-headless'
  CreatedDate: utcNow('yyyy-MM-dd')
  CostCenter: environment == 'prod' ? 'production' : 'development'
  Critical: environment == 'prod' ? 'true' : 'false'
  BackupRequired: environment == 'prod' ? 'true' : 'false'
}

// Cost optimization configuration
var costConfig = {
  basic: {
    storageAccountType: 'Standard_LRS'
    mysqlSku: 'Standard_B1ms'
    redisSku: { name: 'Basic', family: 'C', capacity: 0 }
    containerCpu: json('0.25')
    containerMemory: '0.5Gi'
    logRetentionDays: 7
    frontDoorSku: 'Standard_AzureFrontDoor'
  }
  standard: {
    storageAccountType: 'Standard_GRS'
    mysqlSku: 'Standard_B2s'
    redisSku: { name: 'Standard', family: 'C', capacity: 1 }
    containerCpu: json('0.5')
    containerMemory: '1Gi'
    logRetentionDays: 30
    frontDoorSku: 'Standard_AzureFrontDoor'
  }
  premium: {
    storageAccountType: 'Standard_RAGRS'
    mysqlSku: 'GeneralPurpose_D2ds_v4'
    redisSku: { name: 'Premium', family: 'P', capacity: 1 }
    containerCpu: json('1.0')
    containerMemory: '2Gi'
    logRetentionDays: 90
    frontDoorSku: 'Premium_AzureFrontDoor'
  }
}

var selectedCostConfig = costConfig[costTier]

// Enhanced Key Vault configuration with proper naming
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${resourceNamePrefixWithRegion}'
  location: location
  tags: union(commonTags, {
    Component: 'security'
  })
  properties: {
    sku: {
      family: 'A'
      name: environment == 'prod' ? 'premium' : 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: environment == 'prod' ? 90 : (environment == 'staging' ? 30 : 7)
    enablePurgeProtection: environment == 'prod' ? true : false
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    networkAcls: environment == 'prod' ? {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    } : null
  }
}

// Enhanced secret management with proper rotation metadata
resource mysqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'mysql-admin-password'
  tags: {
    'secret-type': 'database'
    'rotation-frequency': '90-days'
    'last-rotated': utcNow('yyyy-MM-dd')
  }
  properties: {
    value: mysqlAdminPassword
    attributes: {
      enabled: true
    }
  }
}

resource wpDbPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'wordpress-db-password'
  tags: {
    'secret-type': 'database'
    'rotation-frequency': '90-days'
    'last-rotated': utcNow('yyyy-MM-dd')
  }
  properties: {
    value: wordpressDbPassword
    attributes: {
      enabled: true
    }
  }
}

// Generate and store additional WordPress secrets
var wordpressAuthKey = uniqueString(resourceGroup().id, 'auth-key', utcNow())
var wordpressSecureAuthKey = uniqueString(resourceGroup().id, 'secure-auth-key', utcNow())
var wordpressJwtSecret = uniqueString(resourceGroup().id, 'jwt-secret', utcNow())

resource wordpressAuthKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'wordpress-auth-key'
  tags: {
    'secret-type': 'application'
    'rotation-frequency': '30-days'
    'last-rotated': utcNow('yyyy-MM-dd')
  }
  properties: {
    value: wordpressAuthKey
    attributes: {
      enabled: true
    }
  }
}

resource wordpressSecureAuthKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'wordpress-secure-auth-key'
  tags: {
    'secret-type': 'application'
    'rotation-frequency': '30-days'
    'last-rotated': utcNow('yyyy-MM-dd')
  }
  properties: {
    value: wordpressSecureAuthKey
    attributes: {
      enabled: true
    }
  }
}

resource wordpressJwtSecretSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'wordpress-jwt-secret'
  tags: {
    'secret-type': 'application'
    'rotation-frequency': '60-days'
    'last-rotated': utcNow('yyyy-MM-dd')
  }
  properties: {
    value: wordpressJwtSecret
    attributes: {
      enabled: true
    }
  }
}

// Enhanced networking infrastructure
module networking 'networking-enhanced.bicep' = {
  name: 'networking-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefixWithRegion
    location: location
    tags: commonTags
    environment: environment
    enableEnhancedSecurity: enableEnhancedSecurity
  }
}

// Enhanced static hosting infrastructure
module staticHosting 'storage-enhanced.bicep' = {
  name: 'static-hosting-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    resourceNamePrefixWithRegion: resourceNamePrefixWithRegion
    location: location
    tags: commonTags
    domainName: domainName
    environment: environment
    costConfig: selectedCostConfig
    enableMultiRegion: enableMultiRegion
    enableEnhancedSecurity: enableEnhancedSecurity
  }
}

// Enhanced WordPress backend infrastructure (conditional)
module wordpressBackend 'containers-enhanced.bicep' = if (deployWordPressBackend) {
  name: 'wordpress-backend-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefixWithRegion
    location: location
    tags: commonTags
    subnetId: networking.outputs.containerSubnetId
    keyVaultName: keyVault.name
    mysqlAdminUsername: mysqlAdminUsername
    wordpressAdminEmail: wordpressAdminEmail
    environment: environment
    costConfig: selectedCostConfig
    backupRetentionDays: backupRetentionDays
    enableEnhancedSecurity: enableEnhancedSecurity
  }
  dependsOn: [
    mysqlPasswordSecret
    wpDbPasswordSecret
    wordpressAuthKeySecret
    wordpressSecureAuthKeySecret
    wordpressJwtSecretSecret
  ]
}

// Enhanced monitoring infrastructure
module monitoring 'monitoring-enhanced.bicep' = if (enableMonitoring) {
  name: 'monitoring-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefixWithRegion
    location: location
    tags: commonTags
    environment: environment
    costConfig: selectedCostConfig
    enableEnhancedSecurity: enableEnhancedSecurity
    keyVaultId: keyVault.id
    staticHostingResourceIds: staticHosting.outputs.resourceIds
    wordpressBackendResourceIds: deployWordPressBackend ? wordpressBackend.outputs.resourceIds : {}
  }
}

// Budget management for cost control
resource budget 'Microsoft.Consumption/budgets@2023-05-01' = if (environment == 'prod' || environment == 'staging') {
  name: 'budget-${resourceNamePrefix}'
  properties: {
    category: 'Cost'
    amount: environment == 'prod' ? 500 : 200
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: utcNow('yyyy-MM-01')
      endDate: dateTimeAdd(utcNow('yyyy-MM-01'), 'P12M')
    }
    filter: {
      dimensions: {
        name: 'ResourceGroupName'
        operator: 'In'
        values: [
          resourceGroup().name
        ]
      }
    }
    notifications: {
      notification1: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: [
          'devops@example.com'
          'finance@example.com'
        ]
        contactRoles: [
          'Owner'
          'Contributor'
        ]
      }
      notification2: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: [
          'devops@example.com'
          'finance@example.com'
        ]
        contactRoles: [
          'Owner'
        ]
      }
    }
  }
}

// Enhanced outputs with additional metadata
output deploymentMetadata object = {
  deploymentId: deployment().name
  deploymentTime: utcNow()
  environment: environment
  costTier: costTier
  region: location
  resourcePrefix: resourceNamePrefix
}

output resourceGroupName string = resourceGroup().name
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id

output staticHosting object = {
  storageAccountName: staticHosting.outputs.storageAccountName
  staticWebsiteUrl: staticHosting.outputs.staticWebsiteUrl
  frontDoorEndpoint: staticHosting.outputs.frontDoorEndpoint
  cdnEndpoint: staticHosting.outputs.cdnEndpoint
}

output networking object = {
  vnetId: networking.outputs.vnetId
  vnetName: networking.outputs.vnetName
  containerSubnetId: networking.outputs.containerSubnetId
  privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
}

output wordpressBackend object = deployWordPressBackend ? {
  wordpressUrl: wordpressBackend.outputs.wordpressUrl
  mysqlServerName: wordpressBackend.outputs.mysqlServerName
  redisHostname: wordpressBackend.outputs.redisHostname
  containerAppEnvironmentId: wordpressBackend.outputs.containerAppEnvironmentId
} : {}

output monitoring object = enableMonitoring ? {
  applicationInsightsName: monitoring.outputs.applicationInsightsName
  applicationInsightsInstrumentationKey: monitoring.outputs.applicationInsightsInstrumentationKey
  applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
  logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  actionGroupId: monitoring.outputs.actionGroupId
} : {}

output costManagement object = {
  budgetName: environment == 'prod' || environment == 'staging' ? budget.name : ''
  estimatedMonthlyCost: costTier == 'basic' ? 50 : (costTier == 'standard' ? 150 : 300)
  costOptimizationTier: costTier
}

output securityConfiguration object = {
  keyVaultEnabled: true
  rbacEnabled: true
  softDeleteEnabled: true
  purgeProtectionEnabled: environment == 'prod'
  networkRestrictionsEnabled: environment == 'prod'
  enhancedSecurityEnabled: enableEnhancedSecurity
}

output environmentVariables object = {
  WORDPRESS_GRAPHQL_URL: deployWordPressBackend ? '${wordpressBackend.outputs.wordpressUrl}/graphql' : ''
  AZURE_STORAGE_ACCOUNT_NAME: staticHosting.outputs.storageAccountName
  AZURE_FRONT_DOOR_ENDPOINT: staticHosting.outputs.frontDoorEndpoint
  AZURE_KEYVAULT_NAME: keyVault.name
  ENVIRONMENT: environment
  COST_TIER: costTier
  REGION: location
}
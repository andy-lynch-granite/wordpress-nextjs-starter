// Main infrastructure template for WordPress + Next.js on Azure
// Deploys static hosting, WordPress backend, database, and monitoring

@description('Environment name (prod, staging, dev)')
param environment string = 'dev'

@description('Project name prefix for all resources')
param projectName string = 'wordpress-nextjs'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Domain name for the website (without protocol)')
param domainName string = 'example.com'

@description('Enable WordPress backend deployment')
param deployWordPressBackend bool = true

@description('Enable monitoring and logging')
param enableMonitoring bool = true

@description('WordPress admin email')
param wordpressAdminEmail string = 'admin@example.com'

@description('MySQL administrator username')
param mysqlAdminUsername string = 'wpadmin'

@secure()
@description('MySQL administrator password')
param mysqlAdminPassword string

@secure()
@description('WordPress database password')
param wordpressDbPassword string

// Variables
var resourceNamePrefix = '${projectName}-${environment}'
var tags = {
  Environment: environment
  Project: projectName
  ManagedBy: 'Bicep'
  Purpose: 'WordPress-NextJS-Headless'
}

// Key Vault for secrets management
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${resourceNamePrefix}-kv'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
  }
}

// Store secrets in Key Vault
resource mysqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'mysql-admin-password'
  properties: {
    value: mysqlAdminPassword
  }
}

resource wpDbPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'wordpress-db-password'
  properties: {
    value: wordpressDbPassword
  }
}

// Networking infrastructure
module networking 'networking.bicep' = {
  name: 'networking-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    tags: tags
  }
}

// Static hosting infrastructure
module staticHosting 'storage.bicep' = {
  name: 'static-hosting-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    tags: tags
    domainName: domainName
    environment: environment
  }
}

// WordPress backend infrastructure (conditional)
module wordpressBackend 'containers.bicep' = if (deployWordPressBackend) {
  name: 'wordpress-backend-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    tags: tags
    subnetId: networking.outputs.containerSubnetId
    keyVaultName: keyVault.name
    mysqlAdminUsername: mysqlAdminUsername
    wordpressAdminEmail: wordpressAdminEmail
    environment: environment
  }
  dependsOn: [
    mysqlPasswordSecret
    wpDbPasswordSecret
  ]
}

// Monitoring infrastructure (conditional)
module monitoring 'monitoring.bicep' = if (enableMonitoring) {
  name: 'monitoring-deployment'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    tags: tags
    environment: environment
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output keyVaultName string = keyVault.name
output staticWebsiteUrl string = staticHosting.outputs.staticWebsiteUrl
output frontDoorEndpoint string = staticHosting.outputs.frontDoorEndpoint
output storageAccountName string = staticHosting.outputs.storageAccountName
output vnetId string = networking.outputs.vnetId
output wordpressBackendUrl string = deployWordPressBackend ? wordpressBackend.outputs.wordpressUrl : ''
output mysqlServerName string = deployWordPressBackend ? wordpressBackend.outputs.mysqlServerName : ''
output redisHostname string = deployWordPressBackend ? wordpressBackend.outputs.redisHostname : ''
output applicationInsightsInstrumentationKey string = enableMonitoring ? monitoring.outputs.applicationInsightsInstrumentationKey : ''

# Terraform Setup Guide

This guide provides comprehensive instructions for setting up and managing infrastructure using Terraform for the headless WordPress + Next.js application on Azure.

## Table of Contents

1. [Terraform Overview](#terraform-overview)
2. [Project Structure](#project-structure)
3. [Provider Configuration](#provider-configuration)
4. [State Management](#state-management)
5. [Resource Modules](#resource-modules)
6. [Environment Configuration](#environment-configuration)
7. [Variables and Secrets](#variables-and-secrets)
8. [Deployment Pipeline](#deployment-pipeline)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Terraform Overview

### Why Terraform for Azure

```yaml
Terraform_Benefits:
  - Declarative infrastructure as code
  - Multi-cloud support (Azure, AWS, GCP)
  - Rich ecosystem of providers
  - State management and drift detection
  - Plan and apply workflow for safety
  - Module reusability across environments
  - Integration with CI/CD pipelines
  - Community support and documentation
```

### Terraform vs Bicep Comparison

```yaml
Comparison:
  Terraform:
    Pros:
      - Multi-cloud support
      - Mature ecosystem
      - Advanced state management
      - Rich conditional logic
      - Extensive community modules
    Cons:
      - Additional complexity
      - Learning curve
      - State file management
      
  Bicep:
    Pros:
      - Native Azure support
      - ARM template compilation
      - Simpler syntax
      - Azure-optimized
      - No state management needed
    Cons:
      - Azure-only
      - Newer ecosystem
      - Limited conditional logic
```

## Project Structure

### Terraform Directory Layout

```bash
infrastructure/terraform/
├── environments/
│   ├── development/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── production/
│       ├── main.tf
│       ├── terraform.tfvars
│       └── backend.tf
├── modules/
│   ├── container-app/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── database/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── redis/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── shared/
│   ├── variables.tf
│   ├── locals.tf
│   └── data.tf
└── scripts/
    ├── init.sh
    ├── plan.sh
    ├── apply.sh
    └── destroy.sh
```

### Root Module Structure

```hcl
# infrastructure/terraform/environments/production/main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}

# Data sources
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Local values
locals {
  environment = var.environment
  location    = var.location
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Repository  = var.repository_url
  }
}

# Resource Groups
resource "azurerm_resource_group" "main" {
  for_each = toset(var.resource_groups)
  name     = "rg-${each.key}-${local.environment}"
  location = local.location
  tags     = local.common_tags
}

# Call modules
module "networking" {
  source = "../../modules/networking"
  
  environment      = local.environment
  location         = local.location
  resource_group   = azurerm_resource_group.main["networking"].name
  vnet_address_space = var.vnet_address_space
  subnet_prefixes  = var.subnet_prefixes
  tags            = local.common_tags
}

module "database" {
  source = "../../modules/database"
  
  environment           = local.environment
  location              = local.location
  resource_group        = azurerm_resource_group.main["database"].name
  admin_username        = var.db_admin_username
  admin_password        = var.db_admin_password
  sku_name             = var.db_sku_name
  storage_size_gb      = var.db_storage_size_gb
  backup_retention_days = var.db_backup_retention_days
  high_availability    = var.db_high_availability
  subnet_id           = module.networking.database_subnet_id
  tags                = local.common_tags
  
  depends_on = [module.networking]
}

module "redis" {
  source = "../../modules/redis"
  
  environment    = local.environment
  location       = local.location
  resource_group = azurerm_resource_group.main["cache"].name
  sku_name      = var.redis_sku_name
  capacity      = var.redis_capacity
  subnet_id     = module.networking.cache_subnet_id
  tags          = local.common_tags
  
  depends_on = [module.networking]
}

module "storage" {
  source = "../../modules/storage"
  
  environment    = local.environment
  location       = local.location
  resource_group = azurerm_resource_group.main["storage"].name
  account_tier   = var.storage_account_tier
  replication_type = var.storage_replication_type
  containers     = var.storage_containers
  tags          = local.common_tags
}

module "container_app" {
  source = "../../modules/container-app"
  
  environment           = local.environment
  location              = local.location
  resource_group        = azurerm_resource_group.main["app"].name
  container_app_name    = var.container_app_name
  container_image       = var.container_image
  cpu_limit            = var.container_cpu_limit
  memory_limit         = var.container_memory_limit
  min_replicas         = var.container_min_replicas
  max_replicas         = var.container_max_replicas
  environment_variables = var.container_environment_variables
  secrets              = var.container_secrets
  subnet_id           = module.networking.app_subnet_id
  tags                = local.common_tags
  
  depends_on = [module.networking, module.database, module.redis, module.storage]
}

module "monitoring" {
  source = "../../modules/monitoring"
  
  environment    = local.environment
  location       = local.location
  resource_group = azurerm_resource_group.main["monitoring"].name
  workspace_name = var.log_analytics_workspace_name
  retention_days = var.log_analytics_retention_days
  tags          = local.common_tags
}
```

## Provider Configuration

### Azure Provider Setup

```hcl
# infrastructure/terraform/shared/providers.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
  
  # Use environment variables or managed identity for authentication
  # AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
}

# Configure the Azure Active Directory Provider
provider "azuread" {
  # Use the same authentication as azurerm
}

# Random provider for generating passwords and suffixes
provider "random" {}

# TLS provider for certificate generation
provider "tls" {}
```

## State Management

### Remote Backend Configuration

```bash
# Create storage account for Terraform state
STORAGE_ACCOUNT_NAME="tfstate$(openssl rand -hex 4)"
RESOURCE_GROUP_NAME="rg-terraform-state"
CONTAINER_NAME="tfstate"

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create storage account
az storage account create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $STORAGE_ACCOUNT_NAME \
  --sku Standard_LRS \
  --encryption-services blob

# Create storage container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME

echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Container: $CONTAINER_NAME"
```

```hcl
# infrastructure/terraform/environments/production/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatexxx"  # Replace with actual storage account name
    container_name       = "tfstate"
    key                  = "production/wordpress-nextjs.tfstate"
    
    # Optional: Use managed identity for authentication
    use_msi = true
    
    # Optional: Enable state locking
    use_azuread_auth = true
  }
}
```

### Environment-Specific State Files

```hcl
# infrastructure/terraform/environments/development/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatexxx"
    container_name       = "tfstate"
    key                  = "development/wordpress-nextjs.tfstate"
    use_msi             = true
    use_azuread_auth    = true
  }
}

# infrastructure/terraform/environments/staging/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatexxx"
    container_name       = "tfstate"
    key                  = "staging/wordpress-nextjs.tfstate"
    use_msi             = true
    use_azuread_auth    = true
  }
}
```

## Resource Modules

### Database Module

```hcl
# infrastructure/terraform/modules/database/main.tf
resource "random_password" "admin_password" {
  count   = var.admin_password == "" ? 1 : 0
  length  = 32
  special = true
}

resource "azurerm_mysql_flexible_server" "main" {
  name                   = "mysql-${var.project_name}-${var.environment}"
  resource_group_name    = var.resource_group
  location              = var.location
  
  administrator_login    = var.admin_username
  administrator_password = var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result
  
  backup_retention_days = var.backup_retention_days
  geo_redundant_backup_enabled = var.environment == "production" ? true : false
  
  sku_name = var.sku_name
  version  = var.mysql_version
  
  storage {
    size_gb = var.storage_size_gb
    auto_grow_enabled = true
  }
  
  high_availability {
    mode = var.high_availability ? "ZoneRedundant" : "Disabled"
  }
  
  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? [var.maintenance_window] : []
    content {
      day_of_week  = maintenance_window.value.day_of_week
      start_hour   = maintenance_window.value.start_hour
      start_minute = maintenance_window.value.start_minute
    }
  }
  
  tags = var.tags
}

resource "azurerm_mysql_flexible_server_database" "wordpress" {
  name                = "wordpress"
  resource_group_name = var.resource_group
  server_name        = azurerm_mysql_flexible_server.main.name
  charset            = "utf8mb4"
  collation          = "utf8mb4_unicode_ci"
}

# Firewall rules
resource "azurerm_mysql_flexible_server_firewall_rule" "allow_azure_services" {
  name                = "AllowAzureServices"
  resource_group_name = var.resource_group
  server_name        = azurerm_mysql_flexible_server.main.name
  start_ip_address   = "0.0.0.0"
  end_ip_address     = "0.0.0.0"
}

# Configuration parameters
resource "azurerm_mysql_flexible_server_configuration" "slow_query_log" {
  name                = "slow_query_log"
  resource_group_name = var.resource_group
  server_name        = azurerm_mysql_flexible_server.main.name
  value              = "ON"
}

resource "azurerm_mysql_flexible_server_configuration" "long_query_time" {
  name                = "long_query_time"
  resource_group_name = var.resource_group
  server_name        = azurerm_mysql_flexible_server.main.name
  value              = var.environment == "production" ? "2" : "1"
}

# Store password in Key Vault if provided
data "azurerm_key_vault" "main" {
  count               = var.key_vault_name != "" ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group
}

resource "azurerm_key_vault_secret" "db_password" {
  count        = var.key_vault_name != "" ? 1 : 0
  name         = "database-password-${var.environment}"
  value        = var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result
  key_vault_id = data.azurerm_key_vault.main[0].id
  tags         = var.tags
}
```

```hcl
# infrastructure/terraform/modules/database/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "resource_group" {
  description = "Resource group name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "wordpress"
}

variable "admin_username" {
  description = "Database administrator username"
  type        = string
  default     = "dbadmin"
}

variable "admin_password" {
  description = "Database administrator password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sku_name" {
  description = "Database SKU name"
  type        = string
  default     = "Standard_B2s"
}

variable "mysql_version" {
  description = "MySQL version"
  type        = string
  default     = "8.0"
}

variable "storage_size_gb" {
  description = "Database storage size in GB"
  type        = number
  default     = 32
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "high_availability" {
  description = "Enable high availability"
  type        = bool
  default     = false
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day_of_week  = number
    start_hour   = number
    start_minute = number
  })
  default = null
}

variable "key_vault_name" {
  description = "Key Vault name for storing secrets"
  type        = string
  default     = ""
}

variable "key_vault_resource_group" {
  description = "Key Vault resource group name"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```

```hcl
# infrastructure/terraform/modules/database/outputs.tf
output "server_name" {
  description = "MySQL server name"
  value       = azurerm_mysql_flexible_server.main.name
}

output "server_fqdn" {
  description = "MySQL server FQDN"
  value       = azurerm_mysql_flexible_server.main.fqdn
}

output "database_name" {
  description = "WordPress database name"
  value       = azurerm_mysql_flexible_server_database.wordpress.name
}

output "admin_username" {
  description = "Database administrator username"
  value       = azurerm_mysql_flexible_server.main.administrator_login
}

output "connection_string" {
  description = "Database connection string"
  value       = "mysql://${azurerm_mysql_flexible_server.main.administrator_login}:${var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result}@${azurerm_mysql_flexible_server.main.fqdn}:3306/${azurerm_mysql_flexible_server_database.wordpress.name}?sslmode=require"
  sensitive   = true
}
```

### Container App Module

```hcl
# infrastructure/terraform/modules/container-app/main.tf
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.existing_workspace_id == "" ? 1 : 0
  name                = "law-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags               = var.tags
}

locals {
  workspace_id = var.existing_workspace_id != "" ? var.existing_workspace_id : azurerm_log_analytics_workspace.main[0].workspace_id
  workspace_key = var.existing_workspace_key != "" ? var.existing_workspace_key : azurerm_log_analytics_workspace.main[0].primary_shared_key
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.project_name}-${var.environment}"
  location                   = var.location
  resource_group_name        = var.resource_group
  log_analytics_workspace_id = local.workspace_id
  tags                      = var.tags
}

resource "azurerm_container_app" "wordpress" {
  name                         = var.container_app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group
  revision_mode               = "Single"
  tags                        = var.tags

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "wordpress"
      image  = var.container_image
      cpu    = var.cpu_limit
      memory = var.memory_limit

      # Environment variables
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables
      dynamic "env" {
        for_each = var.secrets
        content {
          name        = env.key
          secret_name = env.value
        }
      }
    }

    # HTTP scaling rule
    scale_rule {
      name = "http-scale-rule"
      http_scale_rule {
        concurrent_requests = var.concurrent_requests_threshold
      }
    }

    # CPU scaling rule
    scale_rule {
      name = "cpu-scale-rule"
      custom_scale_rule {
        custom_rule_type = "cpu"
        metadata = {
          type  = "Utilization"
          value = tostring(var.cpu_threshold)
        }
      }
    }
  }

  # Ingress configuration
  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Secrets configuration
  dynamic "secret" {
    for_each = var.key_vault_secrets
    content {
      name                = secret.key
      key_vault_secret_id = secret.value
      identity           = azurerm_user_assigned_identity.main.id
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }
}

# User-assigned managed identity for Key Vault access
resource "azurerm_user_assigned_identity" "main" {
  name                = "id-${var.container_app_name}"
  location            = var.location
  resource_group_name = var.resource_group
  tags               = var.tags
}

# Key Vault access policy for managed identity
data "azurerm_key_vault" "main" {
  count               = var.key_vault_name != "" ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group
}

resource "azurerm_key_vault_access_policy" "container_app" {
  count        = var.key_vault_name != "" ? 1 : 0
  key_vault_id = data.azurerm_key_vault.main[0].id
  tenant_id    = azurerm_user_assigned_identity.main.tenant_id
  object_id    = azurerm_user_assigned_identity.main.principal_id

  secret_permissions = ["Get", "List"]
}
```

### Redis Module

```hcl
# infrastructure/terraform/modules/redis/main.tf
resource "azurerm_redis_cache" "main" {
  name                = "redis-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group
  capacity            = var.capacity
  family              = var.family
  sku_name           = var.sku_name
  
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"
  
  redis_configuration {
    maxmemory_policy = var.maxmemory_policy
  }
  
  # Patch schedule for maintenance
  dynamic "patch_schedule" {
    for_each = var.patch_schedule != null ? [var.patch_schedule] : []
    content {
      day_of_week    = patch_schedule.value.day_of_week
      start_hour_utc = patch_schedule.value.start_hour_utc
    }
  }
  
  tags = var.tags
}

# Store Redis connection string in Key Vault
data "azurerm_key_vault" "main" {
  count               = var.key_vault_name != "" ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group
}

resource "azurerm_key_vault_secret" "redis_connection_string" {
  count        = var.key_vault_name != "" ? 1 : 0
  name         = "redis-connection-string-${var.environment}"
  value        = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port},password=${azurerm_redis_cache.main.primary_access_key},ssl=True,abortConnect=False"
  key_vault_id = data.azurerm_key_vault.main[0].id
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "redis_password" {
  count        = var.key_vault_name != "" ? 1 : 0
  name         = "redis-password-${var.environment}"
  value        = azurerm_redis_cache.main.primary_access_key
  key_vault_id = data.azurerm_key_vault.main[0].id
  tags         = var.tags
}
```

## Environment Configuration

### Production Environment Variables

```hcl
# infrastructure/terraform/environments/production/terraform.tfvars
# Environment Configuration
environment = "production"
location    = "East US"
project_name = "wordpress"
repository_url = "https://github.com/andy-lynch-granite/wordpress-nextjs-starter"

# Resource Groups
resource_groups = [
  "app",
  "database",
  "cache",
  "storage",
  "networking",
  "monitoring",
  "security"
]

# Networking Configuration
vnet_address_space = ["10.0.0.0/16"]
subnet_prefixes = {
  app      = "10.0.1.0/24"
  database = "10.0.2.0/24"
  cache    = "10.0.3.0/24"
  storage  = "10.0.4.0/24"
}

# Database Configuration
db_admin_username      = "dbadmin"
db_sku_name           = "Standard_D2ds_v4"
db_storage_size_gb    = 256
db_backup_retention_days = 35
db_high_availability   = true

# Redis Configuration
redis_sku_name = "Premium"
redis_capacity = 1

# Storage Configuration
storage_account_tier   = "Standard"
storage_replication_type = "GRS"
storage_containers = [
  "uploads",
  "backups",
  "logs"
]

# Container App Configuration
container_app_name     = "ca-wordpress-prod"
container_image        = "acrwordpressprod.azurecr.io/wordpress:latest"
container_cpu_limit    = "2.0"
container_memory_limit = "4.0Gi"
container_min_replicas = 3
container_max_replicas = 20

# Environment Variables for Container App
container_environment_variables = {
  WORDPRESS_DEBUG     = "false"
  WP_ENVIRONMENT_TYPE = "production"
  WORDPRESS_DB_HOST   = "mysql-wordpress-production.mysql.database.azure.com"
  WORDPRESS_DB_NAME   = "wordpress"
  WORDPRESS_DB_USER   = "dbadmin"
  REDIS_HOST         = "redis-wordpress-production.redis.cache.windows.net"
  REDIS_PORT         = "6380"
  LOG_LEVEL          = "warning"
}

# Secret References
container_secrets = {
  WORDPRESS_DB_PASSWORD = "database-password-secret"
  REDIS_PASSWORD       = "redis-password-secret"
  WORDPRESS_AUTH_KEY   = "wordpress-auth-key-secret"
}

# Key Vault Secret References
key_vault_secrets = {
  "database-password-secret" = "/subscriptions/xxx/resourceGroups/rg-security-production/providers/Microsoft.KeyVault/vaults/kv-wordpress-prod/secrets/database-password"
  "redis-password-secret"    = "/subscriptions/xxx/resourceGroups/rg-security-production/providers/Microsoft.KeyVault/vaults/kv-wordpress-prod/secrets/redis-password"
  "wordpress-auth-key-secret" = "/subscriptions/xxx/resourceGroups/rg-security-production/providers/Microsoft.KeyVault/vaults/kv-wordpress-prod/secrets/wordpress-auth-key"
}

# Log Analytics Configuration
log_analytics_workspace_name = "law-wordpress-prod"
log_analytics_retention_days = 90
```

### Development Environment Variables

```hcl
# infrastructure/terraform/environments/development/terraform.tfvars
# Environment Configuration
environment = "development"
location    = "East US"
project_name = "wordpress"
repository_url = "https://github.com/andy-lynch-granite/wordpress-nextjs-starter"

# Resource Groups
resource_groups = [
  "app",
  "database",
  "cache",
  "storage",
  "monitoring"
]

# Networking Configuration (smaller address space for dev)
vnet_address_space = ["10.1.0.0/16"]
subnet_prefixes = {
  app      = "10.1.1.0/24"
  database = "10.1.2.0/24"
  cache    = "10.1.3.0/24"
}

# Database Configuration (smaller for cost savings)
db_admin_username      = "dbadmin"
db_sku_name           = "Standard_B1ms"
db_storage_size_gb    = 32
db_backup_retention_days = 7
db_high_availability   = false

# Redis Configuration (basic tier for dev)
redis_sku_name = "Basic"
redis_capacity = 0

# Storage Configuration
storage_account_tier   = "Standard"
storage_replication_type = "LRS"
storage_containers = [
  "uploads",
  "backups"
]

# Container App Configuration
container_app_name     = "ca-wordpress-dev"
container_image        = "acrwordpressdev.azurecr.io/wordpress:dev-latest"
container_cpu_limit    = "0.5"
container_memory_limit = "1.0Gi"
container_min_replicas = 1
container_max_replicas = 3

# Environment Variables for Container App
container_environment_variables = {
  WORDPRESS_DEBUG     = "true"
  WP_ENVIRONMENT_TYPE = "development"
  WORDPRESS_DB_HOST   = "mysql-wordpress-development.mysql.database.azure.com"
  WORDPRESS_DB_NAME   = "wordpress"
  WORDPRESS_DB_USER   = "dbadmin"
  REDIS_HOST         = "redis-wordpress-development.redis.cache.windows.net"
  REDIS_PORT         = "6380"
  LOG_LEVEL          = "debug"
}

# Log Analytics Configuration
log_analytics_workspace_name = "law-wordpress-dev"
log_analytics_retention_days = 30
```

## Variables and Secrets

### Shared Variables

```hcl
# infrastructure/terraform/shared/variables.tf
variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  
  validation {
    condition = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "location" {
  description = "Azure location for resources"
  type        = string
  default     = "East US"
  
  validation {
    condition = contains([
      "East US", "East US 2", "West US", "West US 2", "West US 3",
      "Central US", "North Central US", "South Central US", "West Central US"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "wordpress"
  
  validation {
    condition     = length(var.project_name) <= 10 && can(regex("^[a-z0-9]+$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric and max 10 characters."
  }
}

variable "resource_groups" {
  description = "List of resource group names to create"
  type        = list(string)
  default = [
    "app",
    "database",
    "cache",
    "storage",
    "monitoring"
  ]
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# Sensitive variables
variable "db_admin_password" {
  description = "Database administrator password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  sensitive   = true
}
```

### Local Values

```hcl
# infrastructure/terraform/shared/locals.tf
locals {
  # Common naming convention
  naming_convention = {
    resource_group      = "rg-${var.project_name}-${var.environment}"
    storage_account     = "sa${var.project_name}${var.environment}${random_string.suffix.result}"
    key_vault          = "kv-${var.project_name}-${var.environment}-${random_string.suffix.result}"
    container_app      = "ca-${var.project_name}-${var.environment}"
    mysql_server       = "mysql-${var.project_name}-${var.environment}"
    redis_cache        = "redis-${var.project_name}-${var.environment}"
    log_analytics      = "law-${var.project_name}-${var.environment}"
  }
  
  # Environment-specific configuration
  environment_config = {
    development = {
      db_sku           = "Standard_B1ms"
      db_storage_gb    = 32
      db_ha_enabled    = false
      redis_sku        = "Basic"
      redis_capacity   = 0
      container_cpu    = "0.5"
      container_memory = "1.0Gi"
      min_replicas     = 1
      max_replicas     = 3
      log_retention    = 30
    }
    
    staging = {
      db_sku           = "Standard_B2s"
      db_storage_gb    = 64
      db_ha_enabled    = false
      redis_sku        = "Standard"
      redis_capacity   = 1
      container_cpu    = "1.0"
      container_memory = "2.0Gi"
      min_replicas     = 2
      max_replicas     = 5
      log_retention    = 60
    }
    
    production = {
      db_sku           = "Standard_D2ds_v4"
      db_storage_gb    = 256
      db_ha_enabled    = true
      redis_sku        = "Premium"
      redis_capacity   = 1
      container_cpu    = "2.0"
      container_memory = "4.0Gi"
      min_replicas     = 3
      max_replicas     = 20
      log_retention    = 90
    }
  }
  
  # Current environment configuration
  current_config = local.environment_config[var.environment]
  
  # Common tags
  common_tags = merge(
    var.tags,
    {
      Environment   = var.environment
      Project      = var.project_name
      ManagedBy    = "Terraform"
      CreatedDate  = formatdate("YYYY-MM-DD", timestamp())
    }
  )
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}
```

## Deployment Pipeline

### Terraform GitHub Actions Workflow

```yaml
# .github/workflows/terraform.yml
name: Terraform Infrastructure

on:
  push:
    paths:
      - 'infrastructure/terraform/**'
    branches: [main, develop]
  pull_request:
    paths:
      - 'infrastructure/terraform/**'
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
        - development
        - staging
        - production
      action:
        description: 'Terraform action'
        required: true
        type: choice
        options:
        - plan
        - apply
        - destroy

env:
  TF_VERSION: '1.6.0'
  ARM_SKIP_PROVIDER_REGISTRATION: true

jobs:
  terraform:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'development' }}
    
    defaults:
      run:
        working-directory: infrastructure/terraform/environments/${{ github.event.inputs.environment || 'development' }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
        
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
        
    - name: Terraform Format Check
      run: terraform fmt -check -recursive
      
    - name: Terraform Init
      run: |
        terraform init \
          -backend-config="resource_group_name=${{ secrets.TERRAFORM_STATE_RG }}" \
          -backend-config="storage_account_name=${{ secrets.TERRAFORM_STATE_STORAGE }}" \
          -backend-config="container_name=tfstate" \
          -backend-config="key=${{ github.event.inputs.environment || 'development' }}/wordpress-nextjs.tfstate"
          
    - name: Terraform Validate
      run: terraform validate
      
    - name: Terraform Plan
      if: github.event.inputs.action == 'plan' || github.event_name == 'pull_request'
      run: |
        terraform plan \
          -var="subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
          -var="tenant_id=${{ secrets.AZURE_TENANT_ID }}" \
          -out=tfplan
          
    - name: Upload Plan Artifact
      if: github.event.inputs.action == 'plan' || github.event_name == 'pull_request'
      uses: actions/upload-artifact@v3
      with:
        name: terraform-plan-${{ github.event.inputs.environment || 'development' }}
        path: infrastructure/terraform/environments/${{ github.event.inputs.environment || 'development' }}/tfplan
        retention-days: 5
        
    - name: Terraform Apply
      if: github.event.inputs.action == 'apply' && github.ref == 'refs/heads/main'
      run: |
        terraform apply \
          -var="subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
          -var="tenant_id=${{ secrets.AZURE_TENANT_ID }}" \
          -auto-approve
          
    - name: Terraform Destroy
      if: github.event.inputs.action == 'destroy'
      run: |
        terraform destroy \
          -var="subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
          -var="tenant_id=${{ secrets.AZURE_TENANT_ID }}" \
          -auto-approve
          
    - name: Terraform Output
      if: github.event.inputs.action == 'apply'
      run: terraform output -json > terraform-outputs.json
      
    - name: Upload Outputs
      if: github.event.inputs.action == 'apply'
      uses: actions/upload-artifact@v3
      with:
        name: terraform-outputs-${{ github.event.inputs.environment || 'development' }}
        path: infrastructure/terraform/environments/${{ github.event.inputs.environment || 'development' }}/terraform-outputs.json
        retention-days: 30
```

### Terraform Scripts

```bash
#!/bin/bash
# infrastructure/terraform/scripts/init.sh

set -e

ENVIRONMENT=${1:-"development"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/../environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    echo "Error: Environment directory $ENV_DIR does not exist"
    exit 1
fi

echo "Initializing Terraform for $ENVIRONMENT environment..."

cd "$ENV_DIR"

# Check if backend configuration exists
if [ ! -f "backend.tf" ]; then
    echo "Error: backend.tf not found in $ENV_DIR"
    exit 1
fi

# Initialize Terraform
terraform init

echo "Terraform initialization completed for $ENVIRONMENT"
```

```bash
#!/bin/bash
# infrastructure/terraform/scripts/plan.sh

set -e

ENVIRONMENT=${1:-"development"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/../environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    echo "Error: Environment directory $ENV_DIR does not exist"
    exit 1
fi

echo "Planning Terraform deployment for $ENVIRONMENT environment..."

cd "$ENV_DIR"

# Ensure Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Terraform not initialized. Running init..."
    terraform init
fi

# Run terraform plan
terraform plan \
    -var-file="terraform.tfvars" \
    -out="tfplan-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S)"

echo "Terraform plan completed for $ENVIRONMENT"
echo "Plan file saved as: tfplan-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S)"
```

```bash
#!/bin/bash
# infrastructure/terraform/scripts/apply.sh

set -e

ENVIRONMENT=${1:-"development"}
PLAN_FILE=${2:-""}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/../environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    echo "Error: Environment directory $ENV_DIR does not exist"
    exit 1
fi

echo "Applying Terraform configuration for $ENVIRONMENT environment..."

cd "$ENV_DIR"

# Confirmation prompt for production
if [ "$ENVIRONMENT" = "production" ]; then
    read -p "Are you sure you want to apply changes to PRODUCTION? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi

# Apply terraform configuration
if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
    echo "Applying from plan file: $PLAN_FILE"
    terraform apply "$PLAN_FILE"
else
    echo "Applying with auto-approve..."
    terraform apply \
        -var-file="terraform.tfvars" \
        -auto-approve
fi

# Output the results
echo "\nTerraform outputs:"
terraform output

echo "\nTerraform apply completed for $ENVIRONMENT"
```

## Best Practices

### Code Organization

1. **Use Modules**: Create reusable modules for common resources
2. **Environment Separation**: Separate environments with different state files
3. **Variable Validation**: Add validation rules to variables
4. **Consistent Naming**: Use consistent naming conventions across resources
5. **Resource Tagging**: Tag all resources with environment, project, and management info

### Security

1. **Sensitive Variables**: Mark sensitive variables appropriately
2. **State File Security**: Store state files in secured Azure Storage
3. **Access Control**: Use RBAC for Terraform execution
4. **Secret Management**: Store secrets in Azure Key Vault, not in Terraform
5. **Network Security**: Implement proper network segmentation

### Performance

1. **Parallel Execution**: Use `-parallelism` flag for faster deployments
2. **Resource Dependencies**: Minimize unnecessary dependencies
3. **State Management**: Keep state files small and organized
4. **Provider Versions**: Pin provider versions for consistency

## Troubleshooting

### Common Issues

#### State File Conflicts

```bash
# If state file is locked
terraform force-unlock <LOCK_ID>

# If state is corrupted
terraform state pull > backup.tfstate
terraform state push backup.tfstate
```

#### Provider Authentication Issues

```bash
# Check Azure CLI authentication
az account show

# Re-authenticate
az login --service-principal \
    -u $AZURE_CLIENT_ID \
    -p $AZURE_CLIENT_SECRET \
    --tenant $AZURE_TENANT_ID
```

#### Resource Import Issues

```bash
# Import existing Azure resource
terraform import azurerm_resource_group.main /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>

# Verify import
terraform plan
```

### Debug Commands

```bash
# Enable debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Validate configuration
terraform validate

# Check formatting
terraform fmt -check -diff

# Show current state
terraform show

# List resources in state
terraform state list

# Show specific resource
terraform state show azurerm_resource_group.main
```

## Next Steps

1. Set up [monitoring and observability](../monitoring/azure-monitor-setup.md)
2. Implement [backup and disaster recovery](../backup-dr/backup-strategy.md)
3. Configure [security hardening](security-hardening.md)
4. Set up [cost optimization](cost-optimization.md) monitoring

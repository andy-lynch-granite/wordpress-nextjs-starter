# Pipeline Troubleshooting Guide

This guide provides comprehensive troubleshooting procedures for GitHub Actions CI/CD pipelines in the headless WordPress + Next.js application.

## Table of Contents

1. [Common Pipeline Issues](#common-pipeline-issues)
2. [Build Failures](#build-failures)
3. [Test Failures](#test-failures)
4. [Deployment Issues](#deployment-issues)
5. [Container Issues](#container-issues)
6. [Azure Service Issues](#azure-service-issues)
7. [Network and Connectivity](#network-and-connectivity)
8. [Security and Authentication](#security-and-authentication)
9. [Performance Issues](#performance-issues)
10. [Monitoring and Debugging](#monitoring-and-debugging)

## Common Pipeline Issues

### Pipeline Workflow Not Triggering

#### Symptoms
```yaml
# Pipeline doesn't start when expected
# No workflow runs appear in Actions tab
# Changes to main branch don't trigger deployment
```

#### Diagnosis
```bash
# Check workflow file syntax
gh workflow list
gh workflow view deploy-production.yml

# Validate YAML syntax
yamllint .github/workflows/deploy-production.yml

# Check branch protection rules
gh api repos/:owner/:repo/branches/main/protection
```

#### Solutions
```yaml
# Common trigger issues and fixes

# Issue: Wrong branch name
on:
  push:
    branches: [main]  # Ensure correct branch name

# Issue: Path filters too restrictive
on:
  push:
    paths:
      - 'src/**'      # Make sure paths include your changes
      - '!**.md'      # Exclude documentation changes if needed

# Issue: Missing permissions
permissions:
  contents: read
  actions: read
  deployments: write
```

### Workflow Permissions Issues

#### Error Messages
```bash
Error: Resource not accessible by integration
Error: You do not have permission to perform this action
HTTP 403: Forbidden
```

#### Solutions
```yaml
# Add explicit permissions to workflow
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      deployments: write
      packages: write
      actions: read
    steps:
      # ... deployment steps
```

```bash
# Check repository settings
gh api repos/:owner/:repo/actions/permissions

# Update repository permissions if needed
gh api repos/:owner/:repo/actions/permissions \
  --method PUT \
  --field enabled=true \
  --field allowed_actions=all
```

## Build Failures

### Node.js Build Issues

#### Common Error: Node Version Mismatch
```bash
Error: The engine "node" is incompatible with this module
Expected version ">= 18.0.0". Got "16.20.0"
```

#### Solution
```yaml
# Fix Node.js version in workflow
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '18'  # Match your project requirements
    cache: 'npm'
    registry-url: 'https://registry.npmjs.org'
```

#### Common Error: NPM Dependencies
```bash
Error: Cannot resolve dependency
npm ERR! peer dep missing
npm ERR! ERESOLVE unable to resolve dependency tree
```

#### Solution
```yaml
# Use clean install and handle peer dependencies
- name: Install dependencies
  run: |
    cd frontend
    npm ci --prefer-offline --no-audit
    # Or force resolution of peer dependencies
    npm install --legacy-peer-deps
```

### PHP Build Issues

#### Common Error: Extension Missing
```bash
PHP Fatal error: Uncaught Error: Call to undefined function mysqli_connect()
PHP Warning: Module 'redis' already loaded
```

#### Solution
```yaml
# Properly configure PHP extensions
- name: Setup PHP
  uses: shivammathur/setup-php@v2
  with:
    php-version: '8.1'
    extensions: mysqli, pdo, pdo_mysql, opcache, redis, curl, mbstring, xml
    ini-values: post_max_size=256M, upload_max_filesize=256M, max_execution_time=300
    coverage: xdebug  # Only if coverage is needed
    tools: composer:v2
```

#### Common Error: Composer Dependencies
```bash
Composer detected issues in your platform:
Your Composer dependencies require PHP version >= 8.1
```

#### Solution
```yaml
# Fix composer platform requirements
- name: Install Composer dependencies
  run: |
    cd wordpress
    composer install --no-dev --optimize-autoloader --no-interaction
    # Or ignore platform requirements if needed
    composer install --ignore-platform-reqs --no-dev
```

## Test Failures

### Unit Test Issues

#### Common Error: Test Database Connection
```bash
PDOException: SQLSTATE[HY000] [2002] Connection refused
WordPress database error
```

#### Solution
```yaml
# Properly configure test database service
services:
  mysql:
    image: mysql:8.0
    env:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: wordpress_test
      MYSQL_USER: wp_user
      MYSQL_PASSWORD: wp_pass
    options: >-
      --health-cmd="mysqladmin ping --silent"
      --health-interval=10s
      --health-timeout=5s
      --health-retries=5
    ports:
      - 3306:3306

steps:
- name: Wait for MySQL
  run: |
    until mysqladmin ping -h 127.0.0.1 -P 3306 --silent; do
      echo 'Waiting for MySQL...'
      sleep 5
    done
```

#### Common Error: Test Environment Variables
```bash
Error: Environment variable WORDPRESS_DB_HOST not set
Undefined constant 'WP_TESTS_DOMAIN'
```

#### Solution
```yaml
# Set test environment variables
- name: Run WordPress tests
  env:
    WP_TESTS_DB_HOST: 127.0.0.1
    WP_TESTS_DB_NAME: wordpress_test
    WP_TESTS_DB_USER: root
    WP_TESTS_DB_PASSWORD: root
    WP_TESTS_DOMAIN: localhost
    WP_TESTS_EMAIL: admin@localhost
  run: |
    cd wordpress
    ./vendor/bin/phpunit --configuration phpunit.xml
```

### Integration Test Failures

#### Common Error: Service Dependencies
```bash
Connection to Redis failed
HTTP 500: Internal Server Error during health check
```

#### Solution
```yaml
# Comprehensive service setup for integration tests
services:
  mysql:
    image: mysql:8.0
    env:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: wordpress
    ports:
      - 3306:3306
      
  redis:
    image: redis:7-alpine
    ports:
      - 6379:6379
      
  wordpress:
    image: wordpress:php8.1-apache
    env:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: root
      WORDPRESS_DB_NAME: wordpress
      REDIS_HOST: redis
    ports:
      - 8080:80
    depends_on:
      - mysql
      - redis

steps:
- name: Wait for services to be ready
  run: |
    # Wait for WordPress to be responsive
    timeout 300 bash -c 'until curl -f http://localhost:8080/wp-admin/install.php; do sleep 5; done'
    
    # Wait for Redis
    timeout 60 bash -c 'until redis-cli -h localhost -p 6379 ping | grep PONG; do sleep 2; done'
```

## Deployment Issues

### Azure Authentication Failures

#### Common Error: Service Principal Issues
```bash
Error: The provided credentials do not have access to resource group
Azure CLI authentication failed
Invalid service principal credentials
```

#### Diagnosis
```bash
# Test Azure credentials locally
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Check service principal permissions
az role assignment list --assignee $AZURE_CLIENT_ID

# Verify resource group access
az group show --name rg-app-prod
```

#### Solution
```yaml
# Ensure proper Azure credentials format in GitHub secrets
# AZURE_CREDENTIALS should be JSON format:
{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```

```bash
# Add required role assignments
az role assignment create \
  --assignee $SERVICE_PRINCIPAL_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-app-prod"

az role assignment create \
  --assignee $SERVICE_PRINCIPAL_ID \
  --role "AcrPush" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-acr-prod/providers/Microsoft.ContainerRegistry/registries/acrwordpressprod"
```

### Container Registry Issues

#### Common Error: Image Push Failures
```bash
Error: unauthorized: authentication required
Error: failed to push image to registry
Error response from daemon: Get https://acrname.azurecr.io/v2/: unauthorized
```

#### Solution
```yaml
# Proper ACR authentication in workflow
- name: Login to Azure Container Registry
  uses: azure/docker-login@v1
  with:
    login-server: ${{ secrets.ACR_LOGIN_SERVER }}
    username: ${{ secrets.ACR_USERNAME }}
    password: ${{ secrets.ACR_PASSWORD }}

# Alternative using Azure CLI
- name: Login to ACR via Azure CLI
  run: |
    az acr login --name ${{ secrets.ACR_NAME }}
```

#### Common Error: Image Size Limits
```bash
Error: image size exceeds registry limits
Error: blob upload unknown
```

#### Solution
```dockerfile
# Optimize Dockerfile to reduce image size
FROM php:8.1-apache AS base

# Multi-stage build to reduce final image size
FROM base AS dependencies
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

FROM base AS final
COPY --from=dependencies /var/www/html/vendor ./vendor
COPY . .

# Clean up unnecessary files
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
```

### Container App Deployment Issues

#### Common Error: Resource Limits
```bash
Error: Container failed to start due to insufficient resources
Error: Container terminated with exit code 137 (OOMKilled)
```

#### Solution
```yaml
# Increase container resources
- name: Deploy Container App
  run: |
    az containerapp update \
      --name ca-wordpress-prod \
      --resource-group rg-app-prod \
      --cpu 2.0 \
      --memory 4.0Gi \
      --min-replicas 1 \
      --max-replicas 10
```

## Container Issues

### Docker Build Failures

#### Common Error: Context Size
```bash
Error: build context too large
Sending build context to Docker daemon  2.1GB
```

#### Solution
```dockerfile
# Create comprehensive .dockerignore
# .dockerignore
node_modules/
.git/
.github/
logs/
*.log
.env.local
.env.development.local
.env.test.local
.env.production.local
coverage/
.nyc_output/
build/
dist/
```

#### Common Error: Layer Caching
```bash
Error: failed to solve with frontend dockerfile.v0
Error: executor failed running
```

#### Solution
```yaml
# Use BuildKit and proper caching
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
  
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ${{ env.REGISTRY }}/wordpress:${{ github.sha }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
    platforms: linux/amd64
```

### Runtime Container Issues

#### Common Error: Environment Variables
```bash
WordPress Error: Database connection failed
PHP Warning: Undefined variable
```

#### Diagnosis
```bash
# Check container app logs
az containerapp logs show \
  --name ca-wordpress-prod \
  --resource-group rg-app-prod \
  --follow

# Check environment variables
az containerapp show \
  --name ca-wordpress-prod \
  --resource-group rg-app-prod \
  --query "properties.template.containers[0].env"
```

#### Solution
```yaml
# Ensure all required environment variables are set
- name: Deploy Container App
  run: |
    az containerapp update \
      --name ca-wordpress-prod \
      --resource-group rg-app-prod \
      --set-env-vars \
        WORDPRESS_DB_HOST=${{ secrets.DB_HOST }} \
        WORDPRESS_DB_NAME=${{ secrets.DB_NAME }} \
        WORDPRESS_DB_USER=${{ secrets.DB_USER }} \
        WORDPRESS_DB_PASSWORD=${{ secrets.DB_PASSWORD }} \
        REDIS_HOST=${{ secrets.REDIS_HOST }} \
        REDIS_PASSWORD=${{ secrets.REDIS_PASSWORD }}
```

## Azure Service Issues

### Resource Group Access Issues

#### Common Error: Insufficient Permissions
```bash
Error: The client does not have authorization to perform action
Microsoft.Resources/subscriptions/resourcegroups/read
```

#### Solution
```bash
# Grant necessary permissions to service principal
az role assignment create \
  --assignee $SERVICE_PRINCIPAL_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# For specific resource groups
az role assignment create \
  --assignee $SERVICE_PRINCIPAL_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-app-prod"
```

### Database Connection Issues

#### Common Error: Firewall Rules
```bash
Error: Client with IP address 'x.x.x.x' is not allowed to access the server
SSL connection is required
```

#### Solution
```bash
# Add GitHub Actions IP ranges to firewall
az mysql flexible-server firewall-rule create \
  --resource-group rg-db-prod \
  --name mysql-wordpress-prod \
  --rule-name AllowGitHubActions \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 255.255.255.255

# Enable SSL enforcement
az mysql flexible-server parameter set \
  --resource-group rg-db-prod \
  --server-name mysql-wordpress-prod \
  --name require_secure_transport \
  --value ON
```

## Network and Connectivity

### DNS Resolution Issues

#### Common Error: Service Discovery
```bash
Error: Could not resolve host: api.example.com
Error: Connection timed out after 30 seconds
```

#### Diagnosis
```bash
# Test DNS resolution in workflow
- name: Test DNS resolution
  run: |
    nslookup api.example.com
    dig api.example.com
    curl -I https://api.example.com/health
```

#### Solution
```yaml
# Add DNS validation steps
- name: Wait for DNS propagation
  run: |
    # Wait for DNS to propagate
    for i in {1..30}; do
      if nslookup api.example.com > /dev/null 2>&1; then
        echo "DNS resolution successful"
        break
      fi
      echo "Waiting for DNS propagation... ($i/30)"
      sleep 10
    done
```

### Load Balancer Issues

#### Common Error: Backend Health Checks
```bash
Error: Backend pool has no healthy endpoints
Application Gateway returning 502 Bad Gateway
```

#### Diagnosis
```bash
# Check Application Gateway backend health
az network application-gateway show-backend-health \
  --name ag-wordpress-prod \
  --resource-group rg-app-prod

# Check container app health
az containerapp replica list \
  --name ca-wordpress-prod \
  --resource-group rg-app-prod
```

#### Solution
```yaml
# Add health check endpoint validation
- name: Validate health checks
  run: |
    # Test container app health directly
    CONTAINER_URL=$(az containerapp show \
      --name ca-wordpress-prod \
      --resource-group rg-app-prod \
      --query "properties.latestRevisionFqdn" -o tsv)
    
    curl -f "https://$CONTAINER_URL/health"
    
    # Test through Application Gateway
    curl -f "https://api.example.com/health"
```

## Security and Authentication

### Secret Management Issues

#### Common Error: Missing Secrets
```bash
Error: Secret 'DATABASE_URL' not found
Error: Required environment variable not set
```

#### Solution
```yaml
# Validate required secrets exist
- name: Validate secrets
  run: |
    if [ -z "${{ secrets.DATABASE_URL }}" ]; then
      echo "Error: DATABASE_URL secret is missing"
      exit 1
    fi
    
    if [ -z "${{ secrets.AZURE_CREDENTIALS }}" ]; then
      echo "Error: AZURE_CREDENTIALS secret is missing"
      exit 1
    fi
```

### Key Vault Access Issues

#### Common Error: Key Vault Permissions
```bash
Error: Access denied to Key Vault
The user, group or application does not have secrets get permission
```

#### Solution
```bash
# Grant Key Vault access to service principal
az keyvault set-policy \
  --name kv-wordpress-prod \
  --object-id $SERVICE_PRINCIPAL_OBJECT_ID \
  --secret-permissions get list

# Use Azure Key Vault action in workflow
- name: Get secrets from Key Vault
  uses: Azure/get-keyvault-secrets@v1
  with:
    keyvault: kv-wordpress-prod
    secrets: 'database-password, redis-password'
  id: secrets
```

## Performance Issues

### Slow Pipeline Execution

#### Common Causes
- Large dependencies download
- Inefficient test execution
- Sequential job execution
- Large Docker build context

#### Solutions
```yaml
# Parallel job execution
jobs:
  test-frontend:
    runs-on: ubuntu-latest
    # ... frontend test steps
    
  test-backend:
    runs-on: ubuntu-latest
    # ... backend test steps
    
  deploy:
    runs-on: ubuntu-latest
    needs: [test-frontend, test-backend]  # Wait for both test jobs
    # ... deployment steps
```

```yaml
# Dependency caching
- name: Cache Node.js dependencies
  uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-

- name: Cache Composer dependencies
  uses: actions/cache@v3
  with:
    path: /tmp/composer-cache
    key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
    restore-keys: |
      ${{ runner.os }}-composer-
```

### Resource Limits

#### Common Error: Runner Out of Memory
```bash
Error: Process completed with exit code 137
GitHub Actions runner out of memory
```

#### Solution
```yaml
# Use larger runners for resource-intensive tasks
jobs:
  build:
    runs-on: ubuntu-latest-8-cores  # Larger runner
    # Or use self-hosted runners
    # runs-on: self-hosted
    
    steps:
    - name: Free up disk space
      run: |
        sudo rm -rf /usr/share/dotnet
        sudo rm -rf /opt/ghc
        sudo rm -rf "/usr/local/share/boost"
        sudo rm -rf "$AGENT_TOOLSDIRECTORY"
```

## Monitoring and Debugging

### Enhanced Logging

```yaml
# Add comprehensive logging to workflows
- name: Debug information
  run: |
    echo "Runner OS: $RUNNER_OS"
    echo "Runner Architecture: $RUNNER_ARCH"
    echo "GitHub SHA: $GITHUB_SHA"
    echo "GitHub Ref: $GITHUB_REF"
    echo "Event Name: $GITHUB_EVENT_NAME"
    
    # System information
    df -h
    free -m
    docker --version
    
    # Environment variables (be careful not to expose secrets)
    env | grep -v PASSWORD | grep -v SECRET | sort
```

### Artifact Collection

```yaml
# Collect logs and artifacts for debugging
- name: Collect logs
  if: failure()
  run: |
    # Collect container logs
    docker-compose logs > docker-compose.logs
    
    # Collect system logs
    sudo journalctl --since "1 hour ago" > system.logs
    
- name: Upload logs as artifacts
  uses: actions/upload-artifact@v3
  if: failure()
  with:
    name: debug-logs
    path: |
      *.logs
      logs/
      coverage/
    retention-days: 7
```

### Pipeline Metrics

```yaml
# Track pipeline performance
- name: Pipeline start time
  run: echo "PIPELINE_START=$(date +%s)" >> $GITHUB_ENV
  
# ... other steps ...

- name: Pipeline metrics
  run: |
    PIPELINE_END=$(date +%s)
    DURATION=$((PIPELINE_END - PIPELINE_START))
    echo "Pipeline duration: ${DURATION} seconds"
    
    # Send metrics to monitoring system
    curl -X POST "${{ secrets.METRICS_ENDPOINT }}" \
      -H "Content-Type: application/json" \
      -d '{
        "metric": "pipeline.duration",
        "value": '${DURATION}',
        "tags": {
          "workflow": "${{ github.workflow }}",
          "branch": "${{ github.ref_name }}",
          "environment": "production"
        }
      }'
```

## Troubleshooting Checklist

### Pre-Deployment Checklist

- [ ] All required secrets are configured
- [ ] Service principal has necessary permissions
- [ ] Resource groups exist and are accessible
- [ ] Container registry is accessible
- [ ] Database and Redis are reachable
- [ ] DNS records are configured correctly
- [ ] SSL certificates are valid and not expired

### During Deployment Issues

1. **Check workflow logs** in GitHub Actions
2. **Verify Azure resource status** in portal
3. **Test service connectivity** manually
4. **Check Azure service health** status
5. **Validate configuration** against documentation
6. **Review recent changes** that might have caused issues

### Post-Deployment Validation

- [ ] Application health checks pass
- [ ] Database connectivity works
- [ ] Cache (Redis) is functioning
- [ ] Load balancer shows healthy backends
- [ ] SSL certificates are properly configured
- [ ] DNS resolution works correctly
- [ ] Monitoring and alerts are active

## Emergency Procedures

### Pipeline Failure During Production Deployment

1. **Stop the deployment immediately**
2. **Initiate rollback procedure**
3. **Notify stakeholders**
4. **Investigate root cause**
5. **Document lessons learned**

```yaml
# Emergency rollback workflow trigger
- name: Emergency rollback
  if: failure()
  uses: ./.github/workflows/rollback.yml
  with:
    environment: production
    rollback_type: full
    target_version: previous
```

### Critical Service Down

```bash
#!/bin/bash
# Emergency service recovery script

ENVIRONMENT=$1
SERVICE=$2

echo "Emergency recovery for $SERVICE in $ENVIRONMENT"

# Scale up service
az containerapp update \
  --name ca-$SERVICE-$ENVIRONMENT \
  --resource-group rg-app-$ENVIRONMENT \
  --min-replicas 3 \
  --max-replicas 10

# Check health
for i in {1..30}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$SERVICE-$ENVIRONMENT.example.com/health)
  if [ $STATUS -eq 200 ]; then
    echo "Service recovery successful"
    break
  fi
  echo "Waiting for service recovery... ($i/30)"
  sleep 10
done
```

## Best Practices

1. **Enable Debug Logging**: Use `ACTIONS_STEP_DEBUG=true` for detailed logs
2. **Use Staging Environment**: Test all changes in staging first
3. **Implement Circuit Breakers**: Stop deployment if critical checks fail
4. **Monitor Pipeline Health**: Set up alerts for pipeline failures
5. **Regular Maintenance**: Keep dependencies and actions up to date
6. **Document Issues**: Maintain a knowledge base of common issues
7. **Test Rollback Procedures**: Regularly test rollback workflows
8. **Use Secrets Safely**: Never expose secrets in logs

## Getting Help

### Internal Resources
- Pipeline documentation
- Team knowledge base
- Previous incident reports

### External Resources
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Docker Documentation](https://docs.docker.com/)

### Support Contacts
- DevOps Team: devops@company.com
- Azure Support: Submit ticket through Azure Portal
- Emergency Hotline: +1-xxx-xxx-xxxx

## Next Steps

1. Set up [secret management](secret-management.md) best practices
2. Configure [automated testing](automated-testing.md) improvements
3. Implement [monitoring and alerting](../monitoring/azure-monitor-setup.md)
4. Review [security hardening](../infrastructure/security-hardening.md) measures

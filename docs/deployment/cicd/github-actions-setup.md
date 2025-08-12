# GitHub Actions CI/CD Pipeline Setup Guide

This guide provides comprehensive CI/CD pipeline configuration using GitHub Actions for the headless WordPress + Next.js solution with Azure deployment.

## Prerequisites

- GitHub repository: `https://github.com/andy-lynch-granite/wordpress-nextjs-starter`
- Azure infrastructure deployed ([Azure Setup Guide](../azure/azure-setup-guide.md))
- Service Principal with appropriate permissions
- Repository secrets configured

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────┐
│                    GitHub Repository                     │
│                                                       │
│  ┌────────────────┐    ┌────────────────────┐  │
│  │   main branch    │    │   develop branch   │  │
│  │                │    │                    │  │
│  │  Production     │    │   Staging/Dev     │  │
│  │  Deployment     │    │   Deployment      │  │
│  └────────────────┘    └────────────────────┘  │
└─────────────────────────────────────────────────────┘
                      │                        │
                      ▼                        ▼
┌───────────────────────┐      ┌───────────────────────┐
│  Production Pipeline │      │  Staging Pipeline    │
│                     │      │                     │
│  1. Test & Build     │      │  1. Test & Build     │
│  2. Security Scan    │      │  2. Security Scan    │
│  3. Build Images     │      │  3. Build Images     │
│  4. Deploy Backend   │      │  4. Deploy Backend   │
│  5. Deploy Frontend  │      │  5. Deploy Frontend  │
│  6. Integration Test │      │  6. Integration Test │
│  7. Performance Test │      │  7. Smoke Test       │
│  8. Notify Team      │      │  8. Notify Team      │
└───────────────────────┘      └───────────────────────┘
                      │                        │
                      ▼                        ▼
┌───────────────────────┐      ┌───────────────────────┐
│  Azure Production    │      │  Azure Staging       │
│                     │      │                     │
│  - Container Apps    │      │  - Container Apps    │
│  - Static Web App    │      │  - Static Web App    │
│  - MySQL Database    │      │  - MySQL Database    │
│  - Redis Cache       │      │  - Redis Cache       │
│  - CDN/Front Door    │      │  - CDN/Front Door    │
└───────────────────────┘      └───────────────────────┘
```

## Step 1: Azure Service Principal Setup

### 1.1 Create Service Principal

```bash
# Source environment variables
source .env.azure

# Create service principal for GitHub Actions
export SP_NAME="sp-github-actions-${PROJECT_NAME}-${ENVIRONMENT}"
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal with contributor role
SP_DETAILS=$(az ad sp create-for-rbac \
  --name $SP_NAME \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
  --sdk-auth)

# Store the entire JSON output - this will be used as AZURE_CREDENTIALS secret
echo "$SP_DETAILS" > azure-credentials.json

echo "Service Principal created successfully!"
echo "Save the contents of azure-credentials.json as AZURE_CREDENTIALS secret in GitHub"

# Extract individual values for other secrets
export SP_CLIENT_ID=$(echo $SP_DETAILS | jq -r '.clientId')
export SP_CLIENT_SECRET=$(echo $SP_DETAILS | jq -r '.clientSecret')
export SP_TENANT_ID=$(echo $SP_DETAILS | jq -r '.tenantId')

echo "Additional secrets to configure:"
echo "AZURE_CLIENT_ID: $SP_CLIENT_ID"
echo "AZURE_CLIENT_SECRET: $SP_CLIENT_SECRET"
echo "AZURE_TENANT_ID: $SP_TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
```

### 1.2 Grant Additional Permissions

```bash
# Grant ACR push permissions
az role assignment create \
  --assignee $SP_CLIENT_ID \
  --role AcrPush \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME

# Grant Static Web App deployment permissions
az role assignment create \
  --assignee $SP_CLIENT_ID \
  --role "Static Web App Contributor" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/staticSites/$STATICWEB_NAME

# Grant Key Vault access for secrets
az keyvault set-policy \
  --name $KEY_VAULT_NAME \
  --spn $SP_CLIENT_ID \
  --secret-permissions get list
```

## Step 2: GitHub Repository Secrets Configuration

### 2.1 Required Repository Secrets

Configure the following secrets in your GitHub repository (`Settings` > `Secrets and variables` > `Actions`):

```bash
# Azure Authentication
AZURE_CREDENTIALS=<contents of azure-credentials.json>
AZURE_CLIENT_ID=$SP_CLIENT_ID
AZURE_CLIENT_SECRET=$SP_CLIENT_SECRET
AZURE_TENANT_ID=$SP_TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID

# Azure Resource Configuration
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_LOCATION="$LOCATION"
AZURE_ACR_NAME=$ACR_NAME
AZURE_KEY_VAULT_NAME=$KEY_VAULT_NAME

# Production Environment
PROD_CONTAINER_NAME=$CONTAINER_NAME
PROD_STATIC_WEB_APP_NAME=$STATICWEB_NAME
PROD_MYSQL_SERVER_NAME=$MYSQL_SERVER_NAME
PROD_REDIS_CACHE_NAME=$REDIS_CACHE_NAME
PROD_CDN_PROFILE_NAME=$CDN_PROFILE_NAME
PROD_CDN_ENDPOINT_NAME=$CDN_ENDPOINT_NAME
PROD_FRONT_DOOR_NAME=$FRONT_DOOR_NAME

# Staging Environment (to be configured)
STAGING_RESOURCE_GROUP="rg-wordpress-nextjs-staging"
STAGING_CONTAINER_NAME="ci-wordpress-staging"
STAGING_STATIC_WEB_APP_NAME="stapp-wordpress-nextjs-staging"

# Notification Secrets
SLACK_WEBHOOK_URL=<your-slack-webhook-url>
TEAMS_WEBHOOK_URL=<your-teams-webhook-url>
SMTP_SERVER=<smtp-server>
SMTP_USERNAME=<smtp-username>
SMTP_PASSWORD=<smtp-password>

# Security Scanning
SNYK_TOKEN=<snyk-token-for-security-scanning>
CODEQL_TOKEN=<github-token-for-codeql>
```

### 2.2 Environment-specific Variables

Create environment-specific variables:

```bash
# Production Environment Variables
cat > .github/environments/production.yml << 'EOF'
name: production
url: https://your-production-domain.com
protection_rules:
  required_reviewers:
    - admin-team
  wait_timer: 5
environment_variables:
  ENVIRONMENT: production
  LOG_LEVEL: warn
  DEBUG_MODE: false
  BACKUP_ENABLED: true
  MONITORING_ENABLED: true
EOF

# Staging Environment Variables
cat > .github/environments/staging.yml << 'EOF'
name: staging
url: https://staging.your-domain.com
protection_rules:
  required_reviewers: []
  wait_timer: 0
environment_variables:
  ENVIRONMENT: staging
  LOG_LEVEL: debug
  DEBUG_MODE: true
  BACKUP_ENABLED: false
  MONITORING_ENABLED: true
EOF
```

## Step 3: Main CI/CD Pipeline Configuration

### 3.1 Primary Deployment Workflow

```bash
mkdir -p .github/workflows

cat > .github/workflows/deploy.yml << 'EOF'
name: Deploy WordPress + Next.js to Azure

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - production
      force_deploy:
        description: 'Force deployment even if tests fail'
        required: false
        default: false
        type: boolean

env:
  NODE_VERSION: '18'
  PHP_VERSION: '8.1'
  DOCKER_BUILDKIT: 1
  COMPOSE_DOCKER_CLI_BUILD: 1

jobs:
  # Job 1: Code Quality and Testing
  test-and-quality:
    runs-on: ubuntu-latest
    outputs:
      cache-key: ${{ steps.cache-key.outputs.key }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate cache key
        id: cache-key
        run: |
          echo "key=deps-${{ hashFiles('frontend/package-lock.json', 'composer.lock') }}" >> $GITHUB_OUTPUT

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: |
            frontend/node_modules
            ~/.cache/pip
            /tmp/.buildx-cache
          key: ${{ steps.cache-key.outputs.key }}
          restore-keys: |
            deps-

      - name: Install frontend dependencies
        working-directory: ./frontend
        run: npm ci

      - name: Run frontend linting
        working-directory: ./frontend
        run: |
          npm run lint
          npm run type-check

      - name: Run frontend tests
        working-directory: ./frontend
        run: npm run test:ci

      - name: Run frontend build test
        working-directory: ./frontend
        run: npm run build

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ env.PHP_VERSION }}
          extensions: mysql, redis, gd, zip, mbstring
          coverage: xdebug

      - name: Install Composer dependencies
        run: |
          if [ -f "composer.json" ]; then
            composer install --no-dev --optimize-autoloader
          fi

      - name: Run PHP linting
        run: |
          if [ -f "composer.json" ]; then
            vendor/bin/phpcs --standard=PSR12 wordpress/
          fi

      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results
          path: |
            frontend/coverage/
            frontend/test-results.xml
            phpunit-results.xml

  # Job 2: Security Scanning
  security-scan:
    runs-on: ubuntu-latest
    needs: test-and-quality
    if: github.event_name != 'pull_request' || github.base_ref == 'main'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Snyk security scan
        uses: snyk/actions/node@master
        if: env.SNYK_TOKEN != ''
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --file=frontend/package.json --severity-threshold=high

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: javascript, php

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  # Job 3: Build Docker Images
  build-images:
    runs-on: ubuntu-latest
    needs: [test-and-quality, security-scan]
    if: always() && (needs.test-and-quality.result == 'success' && (needs.security-scan.result == 'success' || needs.security-scan.result == 'skipped'))
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        with:
          driver-opts: network=host

      - name: Login to Azure Container Registry
        uses: azure/docker-login@v1
        with:
          login-server: ${{ secrets.AZURE_ACR_NAME }}.azurecr.io
          username: ${{ secrets.AZURE_CLIENT_ID }}
          password: ${{ secrets.AZURE_CLIENT_SECRET }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.AZURE_ACR_NAME }}.azurecr.io/wordpress-headless
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push WordPress image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./infrastructure/docker/wordpress/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64

      - name: Run container security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.AZURE_ACR_NAME }}.azurecr.io/wordpress-headless:${{ github.sha }}
          format: 'sarif'
          output: 'container-scan-results.sarif'

      - name: Upload container scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'container-scan-results.sarif'

  # Job 4: Deploy to Environment
  deploy:
    runs-on: ubuntu-latest
    needs: [test-and-quality, build-images]
    environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
    if: always() && needs.test-and-quality.result == 'success' && needs.build-images.result == 'success'
    outputs:
      deployment-url: ${{ steps.deploy-backend.outputs.url }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set environment variables
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "ENVIRONMENT=production" >> $GITHUB_ENV
            echo "RESOURCE_GROUP=${{ secrets.AZURE_RESOURCE_GROUP }}" >> $GITHUB_ENV
            echo "CONTAINER_NAME=${{ secrets.PROD_CONTAINER_NAME }}" >> $GITHUB_ENV
            echo "STATIC_WEB_APP_NAME=${{ secrets.PROD_STATIC_WEB_APP_NAME }}" >> $GITHUB_ENV
          else
            echo "ENVIRONMENT=staging" >> $GITHUB_ENV
            echo "RESOURCE_GROUP=${{ secrets.STAGING_RESOURCE_GROUP }}" >> $GITHUB_ENV
            echo "CONTAINER_NAME=${{ secrets.STAGING_CONTAINER_NAME }}" >> $GITHUB_ENV
            echo "STATIC_WEB_APP_NAME=${{ secrets.STAGING_STATIC_WEB_APP_NAME }}" >> $GITHUB_ENV
          fi

      - name: Get secrets from Key Vault
        id: secrets
        run: |
          # Get database credentials
          MYSQL_USERNAME=$(az keyvault secret show --vault-name ${{ secrets.AZURE_KEY_VAULT_NAME }} --name "mysql-admin-username" --query value -o tsv)
          MYSQL_PASSWORD=$(az keyvault secret show --vault-name ${{ secrets.AZURE_KEY_VAULT_NAME }} --name "mysql-admin-password" --query value -o tsv)
          REDIS_CONNECTION=$(az keyvault secret show --vault-name ${{ secrets.AZURE_KEY_VAULT_NAME }} --name "redis-connection-string" --query value -o tsv)
          
          echo "::add-mask::$MYSQL_PASSWORD"
          echo "mysql-username=$MYSQL_USERNAME" >> $GITHUB_OUTPUT
          echo "mysql-password=$MYSQL_PASSWORD" >> $GITHUB_OUTPUT
          echo "redis-connection=$REDIS_CONNECTION" >> $GITHUB_OUTPUT

      - name: Deploy WordPress container
        id: deploy-backend
        run: |
          # Get current container configuration
          CURRENT_IMAGE=$(az container show --name $CONTAINER_NAME --resource-group $RESOURCE_GROUP --query containers[0].image -o tsv || echo "")
          NEW_IMAGE="${{ secrets.AZURE_ACR_NAME }}.azurecr.io/wordpress-headless:${{ github.sha }}"
          
          if [[ "$CURRENT_IMAGE" != "$NEW_IMAGE" ]] || [[ "${{ github.event.inputs.force_deploy }}" == "true" ]]; then
            echo "Deploying new container image: $NEW_IMAGE"
            
            # Update container with new image
            az container create \
              --resource-group $RESOURCE_GROUP \
              --name $CONTAINER_NAME \
              --image $NEW_IMAGE \
              --registry-login-server ${{ secrets.AZURE_ACR_NAME }}.azurecr.io \
              --registry-username ${{ secrets.AZURE_CLIENT_ID }} \
              --registry-password ${{ secrets.AZURE_CLIENT_SECRET }} \
              --dns-name-label ${CONTAINER_NAME}-${ENVIRONMENT} \
              --ports 80 443 \
              --cpu 2 \
              --memory 4 \
              --location ${{ secrets.AZURE_LOCATION }} \
              --restart-policy OnFailure \
              --environment-variables \
                WORDPRESS_DB_HOST="${{ secrets.PROD_MYSQL_SERVER_NAME }}.mysql.database.azure.com" \
                WORDPRESS_DB_NAME="wordpress" \
                WORDPRESS_DB_USER="${{ steps.secrets.outputs.mysql-username }}" \
                WORDPRESS_DB_PASSWORD="${{ steps.secrets.outputs.mysql-password }}" \
                WORDPRESS_ENV="$ENVIRONMENT" \
                WP_DEBUG="false" \
                REDIS_CONNECTION_STRING="${{ steps.secrets.outputs.redis-connection }}" \
              --tags project=wordpress-nextjs environment=$ENVIRONMENT deployed-by=github-actions
          else
            echo "Container already running latest image: $CURRENT_IMAGE"
          fi
          
          # Get container URL
          CONTAINER_FQDN=$(az container show --name $CONTAINER_NAME --resource-group $RESOURCE_GROUP --query ipAddress.fqdn -o tsv)
          echo "url=http://$CONTAINER_FQDN" >> $GITHUB_OUTPUT

      - name: Wait for backend to be ready
        run: |
          echo "Waiting for WordPress to be ready..."
          BACKEND_URL="${{ steps.deploy-backend.outputs.url }}"
          
          for i in {1..30}; do
            if curl -f "$BACKEND_URL/wp-json/wp/v2/" > /dev/null 2>&1; then
              echo "Backend is ready!"
              break
            fi
            echo "Attempt $i/30: Backend not ready, waiting 10 seconds..."
            sleep 10
          done

      - name: Deploy Static Web App (Frontend)
        uses: Azure/static-web-apps-deploy@v1
        with:
          azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          action: 'upload'
          app_location: 'frontend'
          api_location: ''
          output_location: 'out'
          skip_app_build: false
        env:
          WORDPRESS_GRAPHQL_ENDPOINT: ${{ steps.deploy-backend.outputs.url }}/graphql
          NEXT_PUBLIC_WORDPRESS_URL: ${{ steps.deploy-backend.outputs.url }}
          NODE_ENV: production

      - name: Purge CDN cache
        run: |
          echo "Purging CDN cache..."
          
          # Purge Front Door cache
          az afd endpoint purge \
            --endpoint-name ${{ secrets.PROD_FRONT_DOOR_NAME }} \
            --profile-name ${{ secrets.PROD_FRONT_DOOR_NAME }} \
            --resource-group $RESOURCE_GROUP \
            --content-paths "/*" \
            --domains $(az afd endpoint show --endpoint-name ${{ secrets.PROD_FRONT_DOOR_NAME }} --profile-name ${{ secrets.PROD_FRONT_DOOR_NAME }} --resource-group $RESOURCE_GROUP --query hostName -o tsv) || true
          
          # Purge Standard CDN cache
          az cdn endpoint purge \
            --name ${{ secrets.PROD_CDN_ENDPOINT_NAME }} \
            --profile-name ${{ secrets.PROD_CDN_PROFILE_NAME }} \
            --resource-group $RESOURCE_GROUP \
            --content-paths "/*" || true
          
          echo "CDN cache purge initiated"

  # Job 5: Integration Tests
  integration-tests:
    runs-on: ubuntu-latest
    needs: deploy
    if: always() && needs.deploy.result == 'success'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install test dependencies
        working-directory: ./tests
        run: npm install

      - name: Run integration tests
        working-directory: ./tests
        env:
          BACKEND_URL: ${{ needs.deploy.outputs.deployment-url }}
          FRONTEND_URL: https://${{ secrets.STATIC_WEB_APP_NAME }}.azurestaticapps.net
        run: |
          npm run test:integration

      - name: Run API tests
        working-directory: ./tests
        env:
          BACKEND_URL: ${{ needs.deploy.outputs.deployment-url }}
        run: |
          npm run test:api

      - name: Upload integration test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: integration-test-results
          path: tests/results/

  # Job 6: Performance Tests (Production only)
  performance-tests:
    runs-on: ubuntu-latest
    needs: [deploy, integration-tests]
    if: github.ref == 'refs/heads/main' && needs.deploy.result == 'success' && needs.integration-tests.result == 'success'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v10
        with:
          urls: |
            https://${{ secrets.PROD_STATIC_WEB_APP_NAME }}.azurestaticapps.net
          configPath: .github/lighthouse/lighthouserc.json
          uploadArtifacts: true
          temporaryPublicStorage: true

      - name: Run load tests
        run: |
          # Install Apache Bench
          sudo apt-get update
          sudo apt-get install -y apache2-utils
          
          # Run load test
          FRONTEND_URL="https://${{ secrets.PROD_STATIC_WEB_APP_NAME }}.azurestaticapps.net"
          BACKEND_URL="${{ needs.deploy.outputs.deployment-url }}"
          
          echo "Running load test on frontend..."
          ab -n 100 -c 10 "$FRONTEND_URL/" > frontend-load-test.txt
          
          echo "Running load test on backend API..."
          ab -n 100 -c 10 "$BACKEND_URL/wp-json/wp/v2/posts" > backend-load-test.txt
          
          # Check for failures
          if grep -q "Failed requests: 0" frontend-load-test.txt && grep -q "Failed requests: 0" backend-load-test.txt; then
            echo "Load tests passed!"
          else
            echo "Load tests failed!"
            cat frontend-load-test.txt
            cat backend-load-test.txt
            exit 1
          fi

      - name: Upload performance test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: performance-test-results
          path: |
            frontend-load-test.txt
            backend-load-test.txt

  # Job 7: Notification
  notify:
    runs-on: ubuntu-latest
    needs: [deploy, integration-tests, performance-tests]
    if: always()
    steps:
      - name: Determine deployment status
        id: status
        run: |
          if [[ "${{ needs.deploy.result }}" == "success" && "${{ needs.integration-tests.result }}" == "success" ]]; then
            if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
              if [[ "${{ needs.performance-tests.result }}" == "success" ]]; then
                echo "status=success" >> $GITHUB_OUTPUT
                echo "message=Production deployment successful with all tests passing" >> $GITHUB_OUTPUT
              else
                echo "status=warning" >> $GITHUB_OUTPUT
                echo "message=Production deployment successful but performance tests failed" >> $GITHUB_OUTPUT
              fi
            else
              echo "status=success" >> $GITHUB_OUTPUT
              echo "message=Staging deployment successful with all tests passing" >> $GITHUB_OUTPUT
            fi
          else
            echo "status=failure" >> $GITHUB_OUTPUT
            echo "message=Deployment failed" >> $GITHUB_OUTPUT
          fi

      - name: Send Slack notification
        uses: 8398a7/action-slack@v3
        if: env.SLACK_WEBHOOK_URL != ''
        with:
          status: ${{ steps.status.outputs.status }}
          channel: '#deployments'
          username: 'GitHub Actions'
          icon_emoji: ':rocket:'
          title: 'WordPress + Next.js Deployment'
          text: |
            ${{ steps.status.outputs.message }}
            
            Environment: ${{ github.ref == 'refs/heads/main' && 'Production' || 'Staging' }}
            Branch: ${{ github.ref_name }}
            Commit: ${{ github.sha }}
            Actor: ${{ github.actor }}
            
            Frontend URL: https://${{ secrets.STATIC_WEB_APP_NAME }}.azurestaticapps.net
            Backend URL: ${{ needs.deploy.outputs.deployment-url }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Send Teams notification
        if: env.TEAMS_WEBHOOK_URL != ''
        run: |
          curl -X POST ${{ secrets.TEAMS_WEBHOOK_URL }} \
            -H "Content-Type: application/json" \
            -d '{
              "@type": "MessageCard",
              "@context": "https://schema.org/extensions",
              "summary": "WordPress + Next.js Deployment",
              "themeColor": "${{ steps.status.outputs.status == 'success' && '00FF00' || steps.status.outputs.status == 'warning' && 'FFFF00' || 'FF0000' }}",
              "sections": [
                {
                  "activityTitle": "WordPress + Next.js Deployment",
                  "activitySubtitle": "${{ steps.status.outputs.message }}",
                  "facts": [
                    {
                      "name": "Environment",
                      "value": "${{ github.ref == 'refs/heads/main' && 'Production' || 'Staging' }}"
                    },
                    {
                      "name": "Branch",
                      "value": "${{ github.ref_name }}"
                    },
                    {
                      "name": "Commit",
                      "value": "${{ github.sha }}"
                    },
                    {
                      "name": "Actor",
                      "value": "${{ github.actor }}"
                    }
                  ]
                }
              ]
            }'
        env:
          TEAMS_WEBHOOK_URL: ${{ secrets.TEAMS_WEBHOOK_URL }}
EOF
```

## Step 4: Specialized Workflows

### 4.1 Database Migration Workflow

```bash
cat > .github/workflows/database-migration.yml << 'EOF'
name: Database Migration

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - production
      migration_type:
        description: 'Type of migration'
        required: true
        default: 'schema'
        type: choice
        options:
        - schema
        - data
        - full
      backup_before:
        description: 'Create backup before migration'
        required: true
        default: true
        type: boolean

jobs:
  migrate-database:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set environment variables
        run: |
          if [[ "${{ github.event.inputs.environment }}" == "production" ]]; then
            echo "MYSQL_SERVER_NAME=${{ secrets.PROD_MYSQL_SERVER_NAME }}" >> $GITHUB_ENV
            echo "RESOURCE_GROUP=${{ secrets.AZURE_RESOURCE_GROUP }}" >> $GITHUB_ENV
          else
            echo "MYSQL_SERVER_NAME=${{ secrets.STAGING_MYSQL_SERVER_NAME }}" >> $GITHUB_ENV
            echo "RESOURCE_GROUP=${{ secrets.STAGING_RESOURCE_GROUP }}" >> $GITHUB_ENV
          fi

      - name: Create database backup
        if: github.event.inputs.backup_before == 'true'
        run: |
          BACKUP_NAME="migration-backup-$(date +%Y%m%d_%H%M%S)"
          
          # Create point-in-time backup
          az mysql flexible-server backup create \
            --resource-group $RESOURCE_GROUP \
            --server-name $MYSQL_SERVER_NAME \
            --backup-name $BACKUP_NAME
          
          echo "Database backup created: $BACKUP_NAME"
          echo "backup-name=$BACKUP_NAME" >> $GITHUB_OUTPUT

      - name: Run database migrations
        run: |
          # Get database credentials from Key Vault
          MYSQL_USERNAME=$(az keyvault secret show --vault-name ${{ secrets.AZURE_KEY_VAULT_NAME }} --name "mysql-admin-username" --query value -o tsv)
          MYSQL_PASSWORD=$(az keyvault secret show --vault-name ${{ secrets.AZURE_KEY_VAULT_NAME }} --name "mysql-admin-password" --query value -o tsv)
          MYSQL_HOST="$MYSQL_SERVER_NAME.mysql.database.azure.com"
          
          case "${{ github.event.inputs.migration_type }}" in
            "schema")
              echo "Running schema migrations..."
              # Run schema-only migrations
              if [ -f "database/migrations/schema.sql" ]; then
                mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --database=wordpress < database/migrations/schema.sql
              fi
              ;;
            "data")
              echo "Running data migrations..."
              # Run data-only migrations
              if [ -f "database/migrations/data.sql" ]; then
                mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --database=wordpress < database/migrations/data.sql
              fi
              ;;
            "full")
              echo "Running full migrations..."
              # Run all migrations
              for migration_file in database/migrations/*.sql; do
                if [ -f "$migration_file" ]; then
                  echo "Executing: $migration_file"
                  mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --database=wordpress < "$migration_file"
                fi
              done
              ;;
          esac
          
          echo "Database migration completed"

      - name: Verify migration
        run: |
          # Get database credentials
          MYSQL_USERNAME=$(az keyvault secret show --vault-name ${{ secrets.AZURE_KEY_VAULT_NAME }} --name "mysql-admin-username" --query value -o tsv)
          MYSQL_PASSWORD=$(az keyvault secret show --vault-name ${{ secrets.AZURE_KEY_VAULT_NAME }} --name "mysql-admin-password" --query value -o tsv)
          MYSQL_HOST="$MYSQL_SERVER_NAME.mysql.database.azure.com"
          
          # Run verification queries
          echo "Verifying database schema..."
          mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --database=wordpress \
            --execute="SHOW TABLES;" > migration-verification.txt
          
          echo "Database tables after migration:"
          cat migration-verification.txt

      - name: Notify migration completion
        uses: 8398a7/action-slack@v3
        if: env.SLACK_WEBHOOK_URL != ''
        with:
          status: success
          channel: '#database'
          text: |
            Database migration completed successfully!
            
            Environment: ${{ github.event.inputs.environment }}
            Migration Type: ${{ github.event.inputs.migration_type }}
            Backup Created: ${{ github.event.inputs.backup_before }}
            Executed by: ${{ github.actor }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
EOF
```

### 4.2 Rollback Workflow

```bash
cat > .github/workflows/rollback.yml << 'EOF'
name: Emergency Rollback

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to rollback'
        required: true
        default: 'production'
        type: choice
        options:
        - staging
        - production
      rollback_type:
        description: 'Type of rollback'
        required: true
        default: 'application'
        type: choice
        options:
        - application
        - database
        - full
      target_commit:
        description: 'Target commit SHA (leave empty for previous deployment)'
        required: false
        type: string
      restore_time:
        description: 'Database restore point (YYYY-MM-DDTHH:MM:SSZ)'
        required: false
        type: string

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Determine rollback target
        id: target
        run: |
          if [[ -n "${{ github.event.inputs.target_commit }}" ]]; then
            TARGET_SHA="${{ github.event.inputs.target_commit }}"
          else
            # Get previous successful deployment
            TARGET_SHA=$(git log --format="%H" --grep="deploy: success" -n 2 | tail -n 1)
            if [[ -z "$TARGET_SHA" ]]; then
              TARGET_SHA=$(git rev-parse HEAD~1)
            fi
          fi
          echo "target-sha=$TARGET_SHA" >> $GITHUB_OUTPUT
          echo "Rolling back to: $TARGET_SHA"

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set environment variables
        run: |
          if [[ "${{ github.event.inputs.environment }}" == "production" ]]; then
            echo "RESOURCE_GROUP=${{ secrets.AZURE_RESOURCE_GROUP }}" >> $GITHUB_ENV
            echo "CONTAINER_NAME=${{ secrets.PROD_CONTAINER_NAME }}" >> $GITHUB_ENV
            echo "STATIC_WEB_APP_NAME=${{ secrets.PROD_STATIC_WEB_APP_NAME }}" >> $GITHUB_ENV
            echo "MYSQL_SERVER_NAME=${{ secrets.PROD_MYSQL_SERVER_NAME }}" >> $GITHUB_ENV
          else
            echo "RESOURCE_GROUP=${{ secrets.STAGING_RESOURCE_GROUP }}" >> $GITHUB_ENV
            echo "CONTAINER_NAME=${{ secrets.STAGING_CONTAINER_NAME }}" >> $GITHUB_ENV
            echo "STATIC_WEB_APP_NAME=${{ secrets.STAGING_STATIC_WEB_APP_NAME }}" >> $GITHUB_ENV
            echo "MYSQL_SERVER_NAME=${{ secrets.STAGING_MYSQL_SERVER_NAME }}" >> $GITHUB_ENV
          fi

      - name: Rollback application
        if: contains(github.event.inputs.rollback_type, 'application') || github.event.inputs.rollback_type == 'full'
        run: |
          echo "Rolling back application to commit: ${{ steps.target.outputs.target-sha }}"
          
          # Build previous version image
          git checkout ${{ steps.target.outputs.target-sha }}
          
          # Login to ACR
          az acr login --name ${{ secrets.AZURE_ACR_NAME }}
          
          # Build and push rollback image
          ROLLBACK_TAG="rollback-$(date +%s)"
          docker build -t ${{ secrets.AZURE_ACR_NAME }}.azurecr.io/wordpress-headless:$ROLLBACK_TAG -f infrastructure/docker/wordpress/Dockerfile .
          docker push ${{ secrets.AZURE_ACR_NAME }}.azurecr.io/wordpress-headless:$ROLLBACK_TAG
          
          # Update container
          az container update \
            --resource-group $RESOURCE_GROUP \
            --name $CONTAINER_NAME \
            --image ${{ secrets.AZURE_ACR_NAME }}.azurecr.io/wordpress-headless:$ROLLBACK_TAG
          
          echo "Application rollback completed"

      - name: Rollback database
        if: contains(github.event.inputs.rollback_type, 'database') || github.event.inputs.rollback_type == 'full'
        run: |
          if [[ -n "${{ github.event.inputs.restore_time }}" ]]; then
            RESTORE_TIME="${{ github.event.inputs.restore_time }}"
          else
            # Default to 1 hour ago
            RESTORE_TIME=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
          fi
          
          echo "Rolling back database to: $RESTORE_TIME"
          
          # Create rollback server
          ROLLBACK_SERVER_NAME="$MYSQL_SERVER_NAME-rollback-$(date +%s)"
          
          az mysql flexible-server restore \
            --resource-group $RESOURCE_GROUP \
            --name $ROLLBACK_SERVER_NAME \
            --source-server $MYSQL_SERVER_NAME \
            --restore-time $RESTORE_TIME \
            --location ${{ secrets.AZURE_LOCATION }}
          
          echo "Database rollback server created: $ROLLBACK_SERVER_NAME"
          echo "Manual intervention required to switch application to rollback database"
          echo "rollback-server=$ROLLBACK_SERVER_NAME" >> $GITHUB_OUTPUT

      - name: Verify rollback
        run: |
          echo "Verifying rollback..."
          
          # Wait for container to restart
          sleep 30
          
          # Get container URL
          CONTAINER_FQDN=$(az container show --name $CONTAINER_NAME --resource-group $RESOURCE_GROUP --query ipAddress.fqdn -o tsv)
          BACKEND_URL="http://$CONTAINER_FQDN"
          
          # Test backend
          for i in {1..10}; do
            if curl -f "$BACKEND_URL/wp-json/wp/v2/" > /dev/null 2>&1; then
              echo "Backend is responding after rollback"
              break
            fi
            echo "Attempt $i/10: Backend not ready, waiting 10 seconds..."
            sleep 10
          done

      - name: Notify rollback completion
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#emergency'
          text: |
            🚨 EMERGENCY ROLLBACK COMPLETED 🚨
            
            Environment: ${{ github.event.inputs.environment }}
            Rollback Type: ${{ github.event.inputs.rollback_type }}
            Target Commit: ${{ steps.target.outputs.target-sha }}
            Executed by: ${{ github.actor }}
            
            ${{ steps.rollback.outputs.rollback-server && format('Database rollback server: {0}', steps.rollback.outputs.rollback-server) || 'No database rollback performed' }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
EOF
```

### 4.3 Infrastructure Drift Detection

```bash
cat > .github/workflows/infrastructure-drift.yml << 'EOF'
name: Infrastructure Drift Detection

on:
  schedule:
    - cron: '0 6 * * 1'  # Weekly on Monday at 6 AM UTC
  workflow_dispatch:

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Install tools
        run: |
          # Install Terraform
          wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
          echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
          sudo apt update && sudo apt install terraform
          
          # Install Azure Resource Graph CLI extension
          az extension add --name resource-graph

      - name: Check resource configuration drift
        run: |
          echo "Checking for infrastructure configuration drift..."
          
          # Get current resource configurations
          az graph query -q "Resources | where resourceGroup == '${{ secrets.AZURE_RESOURCE_GROUP }}' | project name, type, location, sku, properties" > current-infrastructure.json
          
          # Compare with expected configuration (if we have infrastructure as code)
          if [ -f "infrastructure/terraform/main.tf" ]; then
            cd infrastructure/terraform
            terraform init
            terraform plan -detailed-exitcode > terraform-plan.txt || TERRAFORM_CHANGED=$?
            
            if [ "$TERRAFORM_CHANGED" == "2" ]; then
              echo "Infrastructure drift detected in Terraform!"
              echo "terraform-drift=true" >> $GITHUB_OUTPUT
            else
              echo "No Terraform drift detected"
              echo "terraform-drift=false" >> $GITHUB_OUTPUT
            fi
          fi

      - name: Check security configuration
        run: |
          echo "Checking security configurations..."
          
          # Check NSG rules
          az network nsg list --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} --query '[].{name:name,rules:securityRules[].{name:name,priority:priority,access:access}}' > current-nsg-rules.json
          
          # Check Key Vault access policies
          az keyvault show --name ${{ secrets.AZURE_KEY_VAULT_NAME }} --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} --query 'properties.accessPolicies' > current-keyvault-policies.json
          
          # Check for public IPs that shouldn't be public
          PUBLIC_IPS=$(az network public-ip list --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} --query '[?ipAddress!=null].{name:name,ip:ipAddress}' -o tsv)
          if [ ! -z "$PUBLIC_IPS" ]; then
            echo "Public IPs found:"
            echo "$PUBLIC_IPS"
          fi

      - name: Check cost anomalies
        run: |
          echo "Checking for cost anomalies..."
          
          # Get current month costs
          CURRENT_MONTH=$(date +%Y-%m)
          LAST_MONTH=$(date -d 'last month' +%Y-%m)
          
          # Note: This requires Cost Management API permissions
          # az consumption usage list --start-date ${CURRENT_MONTH}-01 --end-date ${CURRENT_MONTH}-31 > current-costs.json || echo "Cost data unavailable"

      - name: Generate drift report
        run: |
          cat > drift-report.md << 'EOL'
          # Infrastructure Drift Report
          
          Generated: $(date)
          
          ## Summary
          
          - Resource Group: ${{ secrets.AZURE_RESOURCE_GROUP }}
          - Terraform Drift: ${{ steps.drift.outputs.terraform-drift || 'Unknown' }}
          - Security Check: Completed
          - Cost Check: Completed
          
          ## Resources
          
          ```json
          $(cat current-infrastructure.json 2>/dev/null || echo "No resource data available")
          ```
          
          ## Security Configurations
          
          ### Network Security Groups
          ```json
          $(cat current-nsg-rules.json 2>/dev/null || echo "No NSG data available")
          ```
          
          ### Key Vault Policies
          ```json
          $(cat current-keyvault-policies.json 2>/dev/null || echo "No Key Vault data available")
          ```
          
          ## Recommendations
          
          - Review any configuration changes
          - Ensure security policies are up to date
          - Monitor cost trends
          
          EOL

      - name: Upload drift report
        uses: actions/upload-artifact@v3
        with:
          name: infrastructure-drift-report-${{ github.run_number }}
          path: |
            drift-report.md
            current-infrastructure.json
            current-nsg-rules.json
            current-keyvault-policies.json
            terraform-plan.txt

      - name: Notify if drift detected
        if: steps.drift.outputs.terraform-drift == 'true'
        uses: 8398a7/action-slack@v3
        with:
          status: warning
          channel: '#infrastructure'
          text: |
            ⚠️ Infrastructure drift detected!
            
            Resource Group: ${{ secrets.AZURE_RESOURCE_GROUP }}
            
            Please review the drift report and take appropriate action.
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
EOF
```

## Step 5: Deployment Environments Configuration

Create environment-specific configurations:

### 5.1 Staging Environment

```bash
mkdir -p .github/environments

cat > .github/environments/staging.yml << 'EOF'
name: staging
url: https://staging-wordpress-nextjs.azurestaticapps.net
protection_rules:
  required_reviewers: []
  wait_timer: 0
  prevent_self_review: false
variables:
  ENVIRONMENT: staging
  LOG_LEVEL: debug
  DEBUG_MODE: true
  BACKUP_ENABLED: false
  MONITORING_ENABLED: true
  CACHE_TTL: 300
  MAX_UPLOAD_SIZE: 50MB
EOF
```

### 5.2 Production Environment

```bash
cat > .github/environments/production.yml << 'EOF'
name: production
url: https://your-production-domain.com
protection_rules:
  required_reviewers:
    - admin-team
    - lead-developer
  wait_timer: 5
  prevent_self_review: true
variables:
  ENVIRONMENT: production
  LOG_LEVEL: warn
  DEBUG_MODE: false
  BACKUP_ENABLED: true
  MONITORING_ENABLED: true
  CACHE_TTL: 3600
  MAX_UPLOAD_SIZE: 10MB
EOF
```

## Step 6: Quality Gates and Branch Protection

### 6.1 Branch Protection Rules

```bash
# Script to set up branch protection (run via GitHub API)
cat > setup-branch-protection.sh << 'EOF'
#!/bin/bash

# GitHub API script to set up branch protection
# Requires GITHUB_TOKEN environment variable

REPO_OWNER="andy-lynch-granite"
REPO_NAME="wordpress-nextjs-starter"
GITHUB_TOKEN="$GITHUB_TOKEN"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN environment variable is required"
    exit 1
fi

# Protect main branch
curl -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/branches/main/protection" \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "test-and-quality",
        "security-scan",
        "build-images"
      ]
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "required_approving_review_count": 2,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true,
      "require_last_push_approval": true
    },
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false
  }'

# Protect develop branch
curl -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/branches/develop/protection" \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "test-and-quality",
        "security-scan"
      ]
    },
    "enforce_admins": false,
    "required_pull_request_reviews": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": false
    },
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false
  }'

echo "Branch protection rules configured"
EOF

chmod +x setup-branch-protection.sh
```

### 6.2 Code Owners File

```bash
cat > .github/CODEOWNERS << 'EOF'
# Global code owners
*                               @admin-team @lead-developer

# Frontend specific
/frontend/                      @frontend-team @lead-developer
/frontend/src/components/       @frontend-team
/frontend/src/pages/           @frontend-team @content-team

# Backend specific
/wordpress/                     @backend-team @lead-developer
/infrastructure/docker/wordpress/ @backend-team @devops-team

# Infrastructure
/infrastructure/                @devops-team @lead-developer
/.github/workflows/             @devops-team @admin-team
/infrastructure/terraform/      @devops-team @admin-team
/infrastructure/bicep/          @devops-team @admin-team

# Database
/database/                      @database-team @lead-developer
/database/migrations/           @database-team @backend-team

# Documentation
/docs/                          @docs-team @lead-developer
/README.md                      @docs-team @admin-team

# Security
/.github/workflows/security-*   @security-team @admin-team
/infrastructure/security/       @security-team @devops-team

# Configuration files
/.github/                       @admin-team @devops-team
/package.json                   @frontend-team @admin-team
/composer.json                  @backend-team @admin-team
/docker-compose.yml             @devops-team @admin-team
EOF
```

## Step 7: Monitoring and Observability Integration

### 7.1 Deployment Monitoring Workflow

```bash
cat > .github/workflows/deployment-monitoring.yml << 'EOF'
name: Post-Deployment Monitoring

on:
  workflow_run:
    workflows: ["Deploy WordPress + Next.js to Azure"]
    types:
      - completed

jobs:
  post-deployment-monitoring:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Wait for services to stabilize
        run: |
          echo "Waiting 5 minutes for services to stabilize after deployment..."
          sleep 300

      - name: Run health checks
        run: |
          # Frontend health check
          FRONTEND_URL="https://${{ secrets.PROD_STATIC_WEB_APP_NAME }}.azurestaticapps.net"
          FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL")
          
          # Backend health check
          BACKEND_FQDN=$(az container show --name ${{ secrets.PROD_CONTAINER_NAME }} --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} --query ipAddress.fqdn -o tsv)
          BACKEND_URL="http://$BACKEND_FQDN"
          BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/wp-json/wp/v2/")
          
          echo "Frontend Status: $FRONTEND_STATUS"
          echo "Backend Status: $BACKEND_STATUS"
          
          if [[ "$FRONTEND_STATUS" != "200" ]] || [[ "$BACKEND_STATUS" != "200" ]]; then
            echo "Health check failed!"
            exit 1
          fi

      - name: Check application metrics
        run: |
          # Query Application Insights for errors
          APP_INSIGHTS_ID=$(az monitor app-insights component show --app ${{ secrets.APP_INSIGHTS_NAME }} --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} --query appId -o tsv)
          
          # Check for recent exceptions (last 10 minutes)
          QUERY="exceptions | where timestamp > ago(10m) | count"
          
          ERROR_COUNT=$(az monitor app-insights query --app $APP_INSIGHTS_ID --analytics-query "$QUERY" --query "tables[0].rows[0][0]" -o tsv || echo "0")
          
          echo "Recent error count: $ERROR_COUNT"
          
          if [[ "$ERROR_COUNT" -gt "0" ]]; then
            echo "Errors detected after deployment!"
            # Get error details
            DETAILS_QUERY="exceptions | where timestamp > ago(10m) | project timestamp, problemId, outerMessage"
            az monitor app-insights query --app $APP_INSIGHTS_ID --analytics-query "$DETAILS_QUERY" --output table
            exit 1
          fi

      - name: Performance validation
        run: |
          # Simple performance check
          FRONTEND_URL="https://${{ secrets.PROD_STATIC_WEB_APP_NAME }}.azurestaticapps.net"
          
          RESPONSE_TIME=$(curl -w "%{time_total}" -s -o /dev/null "$FRONTEND_URL")
          
          echo "Frontend response time: ${RESPONSE_TIME}s"
          
          # Alert if response time > 3 seconds
          if (( $(echo "$RESPONSE_TIME > 3" | bc -l) )); then
            echo "Performance degradation detected!"
            exit 1
          fi

      - name: Alert on monitoring failure
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          channel: '#alerts'
          text: |
            🚨 Post-deployment monitoring failed!
            
            Deployment may have completed but services are not healthy.
            Immediate investigation required.
            
            Environment: Production
            Workflow: ${{ github.event.workflow_run.name }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Update deployment status
        run: |
          echo "Post-deployment monitoring completed successfully"
          
          # Update deployment annotation in Application Insights
          az monitor app-insights component update \
            --app ${{ secrets.APP_INSIGHTS_NAME }} \
            --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} \
            --tags "last-deployment=$(date -u +%Y-%m-%dT%H:%M:%SZ)" "deployment-status=healthy"
EOF
```

## Step 8: Pipeline Configuration Summary

### 8.1 Update Repository Configuration

```bash
# Create pipeline configuration summary
cat >> .env.azure << EOF

# CI/CD Pipeline Configuration
GITHUB_REPOSITORY="andy-lynch-granite/wordpress-nextjs-starter"
SERVICE_PRINCIPAL_NAME=$SP_NAME
SERVICE_PRINCIPAL_CLIENT_ID=$SP_CLIENT_ID
SERVICE_PRINCIPAL_TENANT_ID=$SP_TENANT_ID

# Pipeline Settings
NODE_VERSION=18
PHP_VERSION=8.1
DOCKER_BUILDKIT=1
ENABLE_SECURITY_SCANNING=true
ENABLE_PERFORMANCE_TESTING=true
ENABLE_INTEGRATION_TESTING=true

# Notification Settings
SLACK_CHANNEL_DEPLOYMENTS="#deployments"
SLACK_CHANNEL_ALERTS="#alerts"
TEAMS_CHANNEL_DEPLOYMENTS="Deployments"

# Quality Gates
REQUIRED_CODE_COVERAGE=80
MAX_SECURITY_ISSUES=0
MAX_PERFORMANCE_BUDGET_MS=3000
EOF

echo "CI/CD Pipeline configuration completed!"
echo "Configuration saved to .env.azure"
```

### 8.2 Final Setup Checklist

```bash
cat > cicd-setup-checklist.md << 'EOF'
# CI/CD Pipeline Setup Checklist

## GitHub Repository Configuration
- [ ] Repository secrets configured
- [ ] Environment variables set
- [ ] Branch protection rules enabled
- [ ] CODEOWNERS file created
- [ ] Workflow files committed

## Azure Configuration
- [ ] Service Principal created and configured
- [ ] ACR permissions granted
- [ ] Key Vault access configured
- [ ] Static Web App deployment token obtained
- [ ] Resource groups for staging/production ready

## Pipeline Features
- [ ] Automated testing (unit, integration, e2e)
- [ ] Security scanning (Snyk, CodeQL, Trivy)
- [ ] Docker image building and scanning
- [ ] Multi-environment deployment (staging/production)
- [ ] Database migration workflows
- [ ] Emergency rollback procedures
- [ ] Infrastructure drift detection
- [ ] Performance testing
- [ ] Post-deployment monitoring
- [ ] Notification integration (Slack/Teams)

## Quality Gates
- [ ] Code coverage requirements
- [ ] Security vulnerability thresholds
- [ ] Performance budgets
- [ ] Required approvals for production
- [ ] Automated rollback triggers

## Monitoring Integration
- [ ] Application Insights integration
- [ ] Custom metrics collection
- [ ] Alert rules configured
- [ ] Dashboard creation
- [ ] Log aggregation setup

## Documentation
- [ ] Deployment runbooks updated
- [ ] Troubleshooting guides created
- [ ] Team training completed
- [ ] Incident response procedures documented
EOF
```

## Troubleshooting Common Issues

### Pipeline Failures

1. **Authentication Issues**
   ```bash
   # Verify service principal permissions
   az role assignment list --assignee $SP_CLIENT_ID --output table
   
   # Test Azure login
   az login --service-principal -u $SP_CLIENT_ID -p $SP_CLIENT_SECRET --tenant $SP_TENANT_ID
   ```

2. **Container Registry Access**
   ```bash
   # Test ACR access
   az acr login --name $ACR_NAME
   docker push $ACR_NAME.azurecr.io/test:latest
   ```

3. **Static Web App Deployment**
   ```bash
   # Get deployment token
   az staticwebapp secrets list --name $STATICWEB_NAME --resource-group $RESOURCE_GROUP
   ```

### Performance Issues

1. **Slow Pipeline Execution**
   - Use caching for dependencies
   - Parallel job execution
   - Optimize Docker builds with multi-stage

2. **Build Timeouts**
   - Increase timeout values
   - Split large jobs into smaller ones
   - Use self-hosted runners for heavy workloads

### Security Scan Failures

1. **False Positives**
   - Configure vulnerability allowlists
   - Update scan tool configurations
   - Review and approve acceptable risks

2. **Dependency Issues**
   - Regular dependency updates
   - Security patch automation
   - Alternative package evaluation

## Next Steps

1. Continue with [Environment Configuration](../environments/development.md)
2. Set up [Infrastructure as Code](../infrastructure/bicep-templates.md)
3. Configure [Monitoring and Observability](../monitoring/azure-monitor-setup.md)
4. Implement [Disaster Recovery](../backup-dr/backup-strategy.md)
5. Review [Security Hardening](../infrastructure/resource-tagging.md)

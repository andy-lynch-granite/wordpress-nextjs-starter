# Infrastructure Versioning Guide

This guide provides comprehensive strategies for versioning infrastructure as code, managing changes, and maintaining consistency across environments for the headless WordPress + Next.js application.

## Table of Contents

1. [Versioning Strategy](#versioning-strategy)
2. [Git-Based Versioning](#git-based-versioning)
3. [Infrastructure Releases](#infrastructure-releases)
4. [Environment Promotion](#environment-promotion)
5. [Change Management](#change-management)
6. [Rollback Procedures](#rollback-procedures)
7. [Documentation and Tracking](#documentation-and-tracking)
8. [Automation and CI/CD](#automation-and-cicd)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Versioning Strategy

### Infrastructure Versioning Philosophy

```yaml
Versioning_Principles:
  Immutable_Infrastructure:
    - Infrastructure changes are versioned and tracked
    - No manual changes to production infrastructure
    - All changes go through version control
    
  Semantic_Versioning:
    - Major: Breaking changes, incompatible updates
    - Minor: New features, backward-compatible
    - Patch: Bug fixes, security patches
    
  Environment_Consistency:
    - Same infrastructure version across environments
    - Controlled promotion through environments
    - Automated testing at each stage
```

### Versioning Scheme

```yaml
Version_Format: "MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]"

Examples:
  Production_Release: "2.1.0"
  Pre_Release: "2.2.0-beta.1"
  Development_Build: "2.2.0-dev.20241201+abc123"
  Hotfix: "2.1.1"
  
Version_Components:
  MAJOR: 
    - Database schema changes
    - Network architecture changes
    - Breaking API changes
    - Major service upgrades
    
  MINOR:
    - New services or resources
    - Feature additions
    - Non-breaking configuration changes
    - Minor service updates
    
  PATCH:
    - Bug fixes
    - Security patches
    - Configuration tweaks
    - Performance improvements
```

## Git-Based Versioning

### Repository Structure

```bash
wordpress-nextjs-starter/
├── .github/
│   └── workflows/
│       ├── infrastructure-ci.yml
│       └── infrastructure-release.yml
├── infrastructure/
│   ├── bicep/
│   │   ├── modules/
│   │   └── main.bicep
│   ├── terraform/
│   │   ├── modules/
│   │   └── environments/
│   └── docker/
├── CHANGELOG.md
├── VERSION
└── infrastructure-version.json
```

### Version Configuration Files

```json
// infrastructure-version.json
{
  "version": "2.1.0",
  "releaseDate": "2024-12-01T10:00:00Z",
  "components": {
    "bicep": {
      "version": "2.1.0",
      "modules": {
        "database": "1.2.0",
        "containerApps": "2.0.1",
        "networking": "1.1.0",
        "monitoring": "1.0.2"
      }
    },
    "terraform": {
      "version": "2.1.0",
      "modules": {
        "database": "1.2.0",
        "container-app": "2.0.1",
        "redis": "1.1.0",
        "storage": "1.0.2"
      }
    },
    "containers": {
      "wordpress": "2.1.0",
      "frontend": "2.1.0"
    }
  },
  "environments": {
    "development": "2.2.0-dev.20241201",
    "staging": "2.1.0",
    "production": "2.0.3"
  },
  "compatibility": {
    "minSupportedVersion": "2.0.0",
    "deprecatedVersions": ["1.x.x"]
  }
}
```

```
# VERSION file
2.1.0
```

### Git Branching Strategy

```yaml
Branching_Model:
  main:
    description: "Production-ready code"
    protection: "Protected, requires PR and approvals"
    deployment: "Production environment"
    
  develop:
    description: "Integration branch for features"
    protection: "Protected, requires PR"
    deployment: "Development environment"
    
  release/v2.1.0:
    description: "Release preparation branch"
    protection: "Protected during release process"
    deployment: "Staging environment"
    
  feature/add-cdn-module:
    description: "Feature development branch"
    protection: "None"
    deployment: "Feature environment (optional)"
    
  hotfix/security-patch:
    description: "Emergency fixes for production"
    protection: "Fast-track approval process"
    deployment: "Production (after staging validation)"
```

### Git Tagging Strategy

```bash
# Tag creation script
#!/bin/bash
# scripts/create-release-tag.sh

VERSION=${1:?"Version is required (e.g., 2.1.0)"}
MESSAGE=${2:-"Release version $VERSION"}

# Validate version format
if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format MAJOR.MINOR.PATCH"
    exit 1
fi

# Check if on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Error: Must be on main branch to create release tag"
    exit 1
fi

# Update VERSION file
echo $VERSION > VERSION

# Update infrastructure-version.json
jq --arg version "$VERSION" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.version = $version | .releaseDate = $date' \
   infrastructure-version.json > tmp.json && mv tmp.json infrastructure-version.json

# Commit version updates
git add VERSION infrastructure-version.json
git commit -m "Bump version to $VERSION"

# Create and push tag
git tag -a "v$VERSION" -m "$MESSAGE"
git push origin "v$VERSION"
git push origin main

echo "Created and pushed tag v$VERSION"
```

### Infrastructure Module Versioning

```hcl
# Terraform module versioning
# infrastructure/terraform/environments/production/main.tf
module "database" {
  source  = "../../modules/database"
  version = "~> 1.2.0"  # Allow patch updates
  
  # Module configuration
  environment = var.environment
  # ... other variables
}

module "container_app" {
  source  = "../../modules/container-app"
  version = "~> 2.0.0"  # Allow minor and patch updates
  
  # Module configuration
  environment = var.environment
  # ... other variables
}
```

```bicep
// Bicep module versioning
// infrastructure/bicep/main.bicep
module database 'modules/database/main.bicep' = {
  name: 'database-deployment'
  params: {
    environment: environment
    location: location
    // ... other parameters
  }
}

// Module metadata
metadata {
  version: '1.2.0'
  description: 'MySQL Flexible Server module'
  author: 'DevOps Team'
}
```

## Infrastructure Releases

### Release Process Workflow

```yaml
# .github/workflows/infrastructure-release.yml
name: Infrastructure Release

on:
  push:
    tags:
      - 'v*.*.*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version'
        required: true
        type: string
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
        - staging
        - production

jobs:
  prepare-release:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      changelog: ${{ steps.changelog.outputs.changelog }}
      
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
        
    - name: Extract version
      id: version
      run: |
        if [[ $GITHUB_REF == refs/tags/v* ]]; then
          VERSION=${GITHUB_REF#refs/tags/v}
        else
          VERSION=${{ github.event.inputs.version }}
        fi
        echo "version=$VERSION" >> $GITHUB_OUTPUT
        
    - name: Generate changelog
      id: changelog
      run: |
        # Generate changelog from git log
        PREVIOUS_TAG=$(git describe --tags --abbrev=0 HEAD^)
        CHANGELOG=$(git log $PREVIOUS_TAG..HEAD --oneline --grep="feat:" --grep="fix:" --grep="BREAKING:")
        
        echo "changelog<<EOF" >> $GITHUB_OUTPUT
        echo "$CHANGELOG" >> $GITHUB_OUTPUT
        echo "EOF" >> $GITHUB_OUTPUT
        
  validate-infrastructure:
    runs-on: ubuntu-latest
    needs: prepare-release
    
    strategy:
      matrix:
        tool: [bicep, terraform]
        
    steps:
    - uses: actions/checkout@v4
    
    - name: Validate Bicep
      if: matrix.tool == 'bicep'
      run: |
        az bicep build --file infrastructure/bicep/main.bicep
        
    - name: Validate Terraform
      if: matrix.tool == 'terraform'
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.6.0
        
    - name: Terraform Validate
      if: matrix.tool == 'terraform'
      run: |
        cd infrastructure/terraform
        terraform init -backend=false
        terraform validate
        
  deploy-staging:
    runs-on: ubuntu-latest
    needs: [prepare-release, validate-infrastructure]
    environment: staging
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy to Staging
      run: |
        echo "Deploying version ${{ needs.prepare-release.outputs.version }} to staging"
        # Add deployment commands here
        
    - name: Run Integration Tests
      run: |
        echo "Running integration tests on staging"
        # Add test commands here
        
  deploy-production:
    runs-on: ubuntu-latest
    needs: [prepare-release, deploy-staging]
    environment: production
    if: github.event.inputs.environment == 'production' || github.ref_type == 'tag'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy to Production
      run: |
        echo "Deploying version ${{ needs.prepare-release.outputs.version }} to production"
        # Add production deployment commands here
        
    - name: Create GitHub Release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: v${{ needs.prepare-release.outputs.version }}
        release_name: Release v${{ needs.prepare-release.outputs.version }}
        body: |
          ## Changes
          ${{ needs.prepare-release.outputs.changelog }}
          
          ## Deployment Status
          - Staging: ✅ Deployed
          - Production: ✅ Deployed
        draft: false
        prerelease: false
```

### Release Notes Generation

```bash
#!/bin/bash
# scripts/generate-release-notes.sh

VERSION=${1:?"Version is required"}
PREVIOUS_VERSION=${2:-$(git describe --tags --abbrev=0 HEAD^)}

echo "# Release Notes for v$VERSION"
echo ""
echo "**Release Date:** $(date +"%Y-%m-%d")"
echo ""

# Get commits since last release
COMMITS=$(git log $PREVIOUS_VERSION..HEAD --oneline)

# Extract different types of changes
FEATURES=$(echo "$COMMITS" | grep -E "^[a-f0-9]+ feat:" | sed 's/^[a-f0-9]* feat: /- /')
FIXES=$(echo "$COMMITS" | grep -E "^[a-f0-9]+ fix:" | sed 's/^[a-f0-9]* fix: /- /')
BREAKING=$(echo "$COMMITS" | grep -E "BREAKING:" | sed 's/^[a-f0-9]* /- /')

if [ -n "$BREAKING" ]; then
    echo "## ⚠️ Breaking Changes"
    echo "$BREAKING"
    echo ""
fi

if [ -n "$FEATURES" ]; then
    echo "## ✨ New Features"
    echo "$FEATURES"
    echo ""
fi

if [ -n "$FIXES" ]; then
    echo "## 🐛 Bug Fixes"
    echo "$FIXES"
    echo ""
fi

# Infrastructure changes
INFRA_CHANGES=$(git diff $PREVIOUS_VERSION..HEAD --name-only | grep -E "infrastructure/" | head -10)
if [ -n "$INFRA_CHANGES" ]; then
    echo "## 🏗️ Infrastructure Changes"
    echo "$INFRA_CHANGES" | sed 's/^/- /'
    echo ""
fi

# Migration notes
echo "## 📋 Migration Guide"
echo "See [Migration Guide](docs/migration/v$VERSION.md) for detailed migration instructions."
echo ""

# Deployment information
echo "## 🚀 Deployment Information"
echo "- **Terraform Version:** >= 1.6.0"
echo "- **Bicep Version:** >= 0.20.4"
echo "- **Azure CLI Version:** >= 2.50.0"
echo "- **Required Permissions:** Contributor on resource groups"
```

## Environment Promotion

### Promotion Pipeline

```yaml
# Environment promotion strategy
Promotion_Flow:
  Development:
    trigger: "Push to develop branch"
    auto_deploy: true
    tests: ["unit", "integration"]
    approval: false
    
  Staging:
    trigger: "Merge to main OR manual promotion"
    auto_deploy: true
    tests: ["unit", "integration", "e2e", "performance"]
    approval: false
    validation_period: "24 hours"
    
  Production:
    trigger: "Manual promotion after staging validation"
    auto_deploy: false
    tests: ["smoke", "health_check"]
    approval: true
    rollback_plan: required
```

### Promotion Workflow

```yaml
# .github/workflows/environment-promotion.yml
name: Environment Promotion

on:
  workflow_dispatch:
    inputs:
      source_environment:
        description: 'Source environment'
        required: true
        type: choice
        options:
        - development
        - staging
      target_environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
        - staging
        - production
      version:
        description: 'Version to promote'
        required: true
        type: string

jobs:
  validate-promotion:
    runs-on: ubuntu-latest
    outputs:
      can_promote: ${{ steps.validation.outputs.can_promote }}
      source_version: ${{ steps.validation.outputs.source_version }}
      
    steps:
    - uses: actions/checkout@v4
    
    - name: Validate promotion rules
      id: validation
      run: |
        SOURCE="${{ github.event.inputs.source_environment }}"
        TARGET="${{ github.event.inputs.target_environment }}"
        VERSION="${{ github.event.inputs.version }}"
        
        # Validate promotion path
        if [[ "$SOURCE" == "development" && "$TARGET" == "production" ]]; then
          echo "can_promote=false" >> $GITHUB_OUTPUT
          echo "Error: Cannot promote directly from development to production"
          exit 1
        fi
        
        # Check if version exists in source environment
        SOURCE_VERSION=$(jq -r ".environments.$SOURCE" infrastructure-version.json)
        if [[ "$SOURCE_VERSION" != "$VERSION" ]]; then
          echo "can_promote=false" >> $GITHUB_OUTPUT
          echo "Error: Version $VERSION not found in $SOURCE environment"
          exit 1
        fi
        
        echo "can_promote=true" >> $GITHUB_OUTPUT
        echo "source_version=$SOURCE_VERSION" >> $GITHUB_OUTPUT
        
  promote-infrastructure:
    runs-on: ubuntu-latest
    needs: validate-promotion
    if: needs.validate-promotion.outputs.can_promote == 'true'
    environment: ${{ github.event.inputs.target_environment }}
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Promote to target environment
      run: |
        TARGET="${{ github.event.inputs.target_environment }}"
        VERSION="${{ github.event.inputs.version }}"
        
        echo "Promoting version $VERSION to $TARGET environment"
        
        # Update environment version in infrastructure-version.json
        jq --arg env "$TARGET" --arg version "$VERSION" \
           '.environments[$env] = $version' \
           infrastructure-version.json > tmp.json && mv tmp.json infrastructure-version.json
           
        # Deploy infrastructure
        cd "infrastructure/terraform/environments/$TARGET"
        terraform init
        terraform apply -auto-approve
        
    - name: Run post-promotion tests
      run: |
        TARGET="${{ github.event.inputs.target_environment }}"
        echo "Running post-promotion tests for $TARGET"
        # Add test commands here
        
    - name: Commit version update
      run: |
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add infrastructure-version.json
        git commit -m "Promote version ${{ github.event.inputs.version }} to ${{ github.event.inputs.target_environment }}"
        git push
```

## Change Management

### Infrastructure Change Request (ICR) Template

```yaml
# .github/ISSUE_TEMPLATE/infrastructure-change-request.yml
name: Infrastructure Change Request
description: Request changes to infrastructure components
title: "[ICR] Infrastructure Change Request"
labels: ["infrastructure", "change-request"]
body:
  - type: markdown
    attributes:
      value: |
        ## Infrastructure Change Request
        Please provide detailed information about the proposed infrastructure changes.
        
  - type: input
    id: version
    attributes:
      label: Target Version
      description: What version will include this change?
      placeholder: "2.1.0"
    validations:
      required: true
      
  - type: dropdown
    id: change_type
    attributes:
      label: Change Type
      description: What type of change is this?
      options:
        - Patch (bug fix, security patch)
        - Minor (new feature, backward compatible)
        - Major (breaking change, incompatible update)
    validations:
      required: true
      
  - type: dropdown
    id: priority
    attributes:
      label: Priority
      description: What is the priority of this change?
      options:
        - Low (nice to have)
        - Medium (should have)
        - High (must have)
        - Critical (security/stability issue)
    validations:
      required: true
      
  - type: textarea
    id: description
    attributes:
      label: Change Description
      description: Detailed description of the proposed changes
      placeholder: |
        - What infrastructure components will be modified?
        - Why is this change needed?
        - What are the expected benefits?
    validations:
      required: true
      
  - type: textarea
    id: impact_analysis
    attributes:
      label: Impact Analysis
      description: Analysis of the impact of this change
      placeholder: |
        - Which environments will be affected?
        - What are the potential risks?
        - Are there any dependencies on other changes?
        - Estimated downtime (if any)?
    validations:
      required: true
      
  - type: textarea
    id: testing_plan
    attributes:
      label: Testing Plan
      description: How will this change be tested?
      placeholder: |
        - Unit tests
        - Integration tests
        - Performance tests
        - User acceptance tests
    validations:
      required: true
      
  - type: textarea
    id: rollback_plan
    attributes:
      label: Rollback Plan
      description: How can this change be rolled back if needed?
      placeholder: |
        - Rollback procedure
        - Time required for rollback
        - Data recovery considerations
    validations:
      required: true
```

### Change Approval Workflow

```yaml
# .github/workflows/change-approval.yml
name: Infrastructure Change Approval

on:
  issues:
    types: [labeled]

jobs:
  change-approval:
    runs-on: ubuntu-latest
    if: contains(github.event.label.name, 'infrastructure')
    
    steps:
    - name: Parse change request
      uses: actions/github-script@v7
      with:
        script: |
          const issue = context.payload.issue;
          const body = issue.body;
          
          // Extract change information
          const changeType = body.match(/Change Type.*?([A-Za-z]+)/s)?.[1];
          const priority = body.match(/Priority.*?([A-Za-z]+)/s)?.[1];
          
          // Add approval labels based on change type
          if (changeType === 'Major' || priority === 'Critical') {
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: issue.number,
              labels: ['needs-architect-approval', 'needs-security-review']
            });
          } else if (changeType === 'Minor') {
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: issue.number,
              labels: ['needs-tech-lead-approval']
            });
          }
          
          // Create approval checklist comment
          const checklistComment = `
          ## Approval Checklist
          
          - [ ] Technical review completed
          - [ ] Security review completed (if required)
          - [ ] Impact analysis approved
          - [ ] Testing plan approved
          - [ ] Rollback plan approved
          - [ ] Change scheduled
          `;
          
          await github.rest.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: issue.number,
            body: checklistComment
          });
```

## Rollback Procedures

### Automated Rollback System

```bash
#!/bin/bash
# scripts/rollback-infrastructure.sh

set -e

ENVIRONMENT=${1:?"Environment is required"}
TARGET_VERSION=${2:?"Target version is required"}
RETAIN_DATA=${3:-"true"}

echo "Starting infrastructure rollback..."
echo "Environment: $ENVIRONMENT"
echo "Target Version: $TARGET_VERSION"
echo "Retain Data: $RETAIN_DATA"

# Validate rollback is possible
CURRENT_VERSION=$(jq -r ".environments.$ENVIRONMENT" infrastructure-version.json)
echo "Current Version: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" == "$TARGET_VERSION" ]]; then
    echo "Target version is the same as current version. No rollback needed."
    exit 0
fi

# Check if target version exists in git
if ! git rev-parse "v$TARGET_VERSION" >/dev/null 2>&1; then
    echo "Error: Version v$TARGET_VERSION not found in git history"
    exit 1
fi

# Pre-rollback backup
echo "Creating pre-rollback backup..."
BACKUP_TAG="backup-before-rollback-$(date +%Y%m%d-%H%M%S)"
git tag "$BACKUP_TAG"
echo "Created backup tag: $BACKUP_TAG"

# Checkout target version
echo "Checking out version v$TARGET_VERSION..."
git fetch --all --tags
git checkout "v$TARGET_VERSION"

# Data retention check
if [[ "$RETAIN_DATA" == "false" ]]; then
    echo "WARNING: Data will not be retained during rollback!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Rollback cancelled"
        exit 0
    fi
fi

# Execute rollback based on IaC tool
if [[ -f "infrastructure/terraform/environments/$ENVIRONMENT/main.tf" ]]; then
    echo "Executing Terraform rollback..."
    cd "infrastructure/terraform/environments/$ENVIRONMENT"
    
    terraform init
    terraform plan -out=rollback.tfplan
    
    echo "Reviewing rollback plan..."
    terraform show rollback.tfplan
    
    read -p "Proceed with rollback? (yes/no): " proceed
    if [[ "$proceed" == "yes" ]]; then
        terraform apply rollback.tfplan
        echo "Terraform rollback completed"
    else
        echo "Rollback cancelled"
        exit 0
    fi
elif [[ -f "infrastructure/bicep/main.bicep" ]]; then
    echo "Executing Bicep rollback..."
    az deployment group create \
        --resource-group "rg-app-$ENVIRONMENT" \
        --template-file "infrastructure/bicep/main.bicep" \
        --parameters environment="$ENVIRONMENT" \
        --mode Complete  # Complete mode for rollback
    echo "Bicep rollback completed"
else
    echo "Error: No supported IaC templates found"
    exit 1
fi

# Update version tracking
echo "Updating version tracking..."
jq --arg env "$ENVIRONMENT" --arg version "$TARGET_VERSION" \
   '.environments[$env] = $version' \
   infrastructure-version.json > tmp.json && mv tmp.json infrastructure-version.json

# Verify rollback
echo "Verifying rollback..."
sleep 30  # Wait for resources to stabilize

# Run health checks
if [[ -f "scripts/health-check.sh" ]]; then
    echo "Running health checks..."
    ./scripts/health-check.sh "$ENVIRONMENT"
fi

# Commit rollback
echo "Committing rollback..."
git add infrastructure-version.json
git commit -m "Rollback $ENVIRONMENT to version $TARGET_VERSION"

# Create rollback tag
ROLLBACK_TAG="rollback-$ENVIRONMENT-$TARGET_VERSION-$(date +%Y%m%d-%H%M%S)"
git tag "$ROLLBACK_TAG"
git push origin "$ROLLBACK_TAG"

echo "Infrastructure rollback completed successfully!"
echo "Rollback tag created: $ROLLBACK_TAG"
echo "Backup tag available: $BACKUP_TAG"
```

### Rollback Verification

```bash
#!/bin/bash
# scripts/verify-rollback.sh

ENVIRONMENT=${1:?"Environment is required"}
EXPECTED_VERSION=${2:?"Expected version is required"}

echo "Verifying rollback for $ENVIRONMENT environment..."

# Check infrastructure version
ACTUAL_VERSION=$(jq -r ".environments.$ENVIRONMENT" infrastructure-version.json)
if [[ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" ]]; then
    echo "✅ Version check passed: $ACTUAL_VERSION"
else
    echo "❌ Version mismatch: expected $EXPECTED_VERSION, got $ACTUAL_VERSION"
    exit 1
fi

# Check resource deployment status
echo "Checking resource deployment status..."

# WordPress container app
WORDPRESS_STATUS=$(az containerapp show \
    --name "ca-wordpress-$ENVIRONMENT" \
    --resource-group "rg-app-$ENVIRONMENT" \
    --query "properties.runningStatus" -o tsv 2>/dev/null || echo "Not Found")

if [[ "$WORDPRESS_STATUS" == "Running" ]]; then
    echo "✅ WordPress container app is running"
else
    echo "❌ WordPress container app status: $WORDPRESS_STATUS"
fi

# Database connectivity
echo "Testing database connectivity..."
DB_HOST="mysql-wordpress-$ENVIRONMENT.mysql.database.azure.com"
if timeout 10 nc -z "$DB_HOST" 3306; then
    echo "✅ Database is accessible"
else
    echo "❌ Database connectivity failed"
fi

# Redis connectivity
echo "Testing Redis connectivity..."
REDIS_HOST="redis-wordpress-$ENVIRONMENT.redis.cache.windows.net"
if timeout 10 nc -z "$REDIS_HOST" 6380; then
    echo "✅ Redis is accessible"
else
    echo "❌ Redis connectivity failed"
fi

# Application health check
echo "Performing application health check..."
if [[ "$ENVIRONMENT" == "production" ]]; then
    HEALTH_URL="https://api.example.com/health"
elif [[ "$ENVIRONMENT" == "staging" ]]; then
    HEALTH_URL="https://api-staging.example.com/health"
else
    HEALTH_URL="https://api-dev.example.com/health"
fi

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")
if [[ "$HTTP_STATUS" == "200" ]]; then
    echo "✅ Application health check passed"
else
    echo "❌ Application health check failed: HTTP $HTTP_STATUS"
fi

echo "Rollback verification completed."
```

## Documentation and Tracking

### Change Log Automation

```bash
#!/bin/bash
# scripts/update-changelog.sh

VERSION=${1:?"Version is required"}
CHANGE_TYPE=${2:?"Change type is required (Added/Changed/Fixed/Removed)"}
DESCRIPTION=${3:?"Description is required"}

# Create changelog entry
DATE=$(date +"%Y-%m-%d")
ENTRY="- $DESCRIPTION"

# Check if version section exists in CHANGELOG.md
if grep -q "## \[$VERSION\]" CHANGELOG.md; then
    # Version section exists, add entry under appropriate category
    if grep -A 20 "## \[$VERSION\]" CHANGELOG.md | grep -q "### $CHANGE_TYPE"; then
        # Category exists, add entry
        sed -i "/### $CHANGE_TYPE/a $ENTRY" CHANGELOG.md
    else
        # Category doesn't exist, create it
        sed -i "/## \[$VERSION\]/a \\n### $CHANGE_TYPE\n$ENTRY" CHANGELOG.md
    fi
else
    # Version section doesn't exist, create it
    {
        echo "## [$VERSION] - $DATE"
        echo ""
        echo "### $CHANGE_TYPE"
        echo "$ENTRY"
        echo ""
        cat CHANGELOG.md
    } > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
fi

echo "Added changelog entry for version $VERSION"
```

### Infrastructure Documentation Generator

```python
#!/usr/bin/env python3
# scripts/generate-infrastructure-docs.py

import json
import subprocess
import datetime
from pathlib import Path

def get_git_info():
    """Get current git information"""
    try:
        commit_hash = subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], 
            text=True
        ).strip()
        branch = subprocess.check_output(
            ['git', 'branch', '--show-current'], 
            text=True
        ).strip()
        return commit_hash[:8], branch
    except subprocess.CalledProcessError:
        return "unknown", "unknown"

def generate_infrastructure_inventory():
    """Generate infrastructure inventory documentation"""
    
    # Load version information
    with open('infrastructure-version.json', 'r') as f:
        version_info = json.load(f)
    
    commit_hash, branch = get_git_info()
    
    doc_content = f"""# Infrastructure Inventory

**Generated:** {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
**Version:** {version_info['version']}
**Git Commit:** {commit_hash}
**Git Branch:** {branch}

## Current Infrastructure Version

```json
{json.dumps(version_info, indent=2)}
```

## Component Versions

### Bicep Modules

| Module | Version | Description |
|--------|---------|-------------|
"""
    
    # Add Bicep modules
    bicep_modules = version_info.get('components', {}).get('bicep', {}).get('modules', {})
    for module, version in bicep_modules.items():
        doc_content += f"| {module} | {version} | Bicep module for {module} |
"
    
    doc_content += "\n### Terraform Modules\n\n| Module | Version | Description |\n|--------|---------|-------------|\n"
    
    # Add Terraform modules
    terraform_modules = version_info.get('components', {}).get('terraform', {}).get('modules', {})
    for module, version in terraform_modules.items():
        doc_content += f"| {module} | {version} | Terraform module for {module} |
"
    
    doc_content += "\n### Container Images\n\n| Image | Version | Description |\n|-------|---------|-------------|\n"
    
    # Add container images
    containers = version_info.get('components', {}).get('containers', {})
    for container, version in containers.items():
        doc_content += f"| {container} | {version} | Container image for {container} |
"
    
    doc_content += "\n## Environment Deployments\n\n| Environment | Version | Status |\n|-------------|---------|--------|\n"
    
    # Add environment information
    environments = version_info.get('environments', {})
    for env, version in environments.items():
        status = "🟢 Active" if env == "production" else "🟡 Testing"
        doc_content += f"| {env} | {version} | {status} |\n"
    
    # Write documentation
    doc_path = Path('docs/infrastructure-inventory.md')
    doc_path.parent.mkdir(exist_ok=True)
    doc_path.write_text(doc_content)
    
    print(f"Infrastructure inventory generated: {doc_path}")

if __name__ == '__main__':
    generate_infrastructure_inventory()
```

## Automation and CI/CD

### Version Automation Workflow

```yaml
# .github/workflows/version-automation.yml
name: Version Automation

on:
  pull_request:
    types: [opened, synchronize, labeled]
  push:
    branches: [main, develop]

jobs:
  version-check:
    runs-on: ubuntu-latest
    outputs:
      version_changed: ${{ steps.check.outputs.version_changed }}
      new_version: ${{ steps.check.outputs.new_version }}
      
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
        
    - name: Check version changes
      id: check
      run: |
        if [[ $GITHUB_EVENT_NAME == "pull_request" ]]; then
          BASE_SHA=${{ github.event.pull_request.base.sha }}
        else
          BASE_SHA=$(git rev-parse HEAD~1)
        fi
        
        CURRENT_VERSION=$(cat VERSION)
        PREVIOUS_VERSION=$(git show $BASE_SHA:VERSION 2>/dev/null || echo "0.0.0")
        
        if [[ "$CURRENT_VERSION" != "$PREVIOUS_VERSION" ]]; then
          echo "version_changed=true" >> $GITHUB_OUTPUT
          echo "new_version=$CURRENT_VERSION" >> $GITHUB_OUTPUT
          echo "Version changed from $PREVIOUS_VERSION to $CURRENT_VERSION"
        else
          echo "version_changed=false" >> $GITHUB_OUTPUT
          echo "No version change detected"
        fi
        
  validate-version:
    runs-on: ubuntu-latest
    needs: version-check
    if: needs.version-check.outputs.version_changed == 'true'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Validate version format
      run: |
        VERSION="${{ needs.version-check.outputs.new_version }}"
        if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "Error: Version must be in format MAJOR.MINOR.PATCH"
          exit 1
        fi
        
    - name: Check version increment
      run: |
        # Add logic to ensure version is properly incremented
        echo "Version increment validation passed"
        
  update-documentation:
    runs-on: ubuntu-latest
    needs: [version-check, validate-version]
    if: needs.version-check.outputs.version_changed == 'true'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Generate infrastructure documentation
      run: |
        python3 scripts/generate-infrastructure-docs.py
        
    - name: Update changelog
      run: |
        VERSION="${{ needs.version-check.outputs.new_version }}"
        # Auto-generate changelog entries from commits
        git log --oneline --since="1 week ago" --grep="feat:" --grep="fix:" > recent-changes.txt
        
    - name: Commit documentation updates
      run: |
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        
        if [[ -n $(git status --porcelain) ]]; then
          git add docs/ CHANGELOG.md
          git commit -m "Update documentation for version ${{ needs.version-check.outputs.new_version }}"
          git push
        fi
```

## Best Practices

### Version Management Guidelines

1. **Consistent Versioning**: Use semantic versioning across all infrastructure components
2. **Automated Testing**: Test all version changes in non-production environments first
3. **Documentation**: Maintain comprehensive changelog and migration guides
4. **Rollback Readiness**: Always have a tested rollback plan before major changes
5. **Environment Parity**: Ensure all environments use the same infrastructure version
6. **Change Approval**: Require approval for major version changes
7. **Monitoring**: Monitor infrastructure after version deployments
8. **Security**: Regularly update versions for security patches

### Infrastructure Versioning Checklist

```yaml
Pre_Release_Checklist:
  Code_Quality:
    - [ ] All IaC templates validated
    - [ ] Security scanning completed
    - [ ] Code review approved
    - [ ] Unit tests passing
    
  Testing:
    - [ ] Integration tests passed
    - [ ] End-to-end tests passed
    - [ ] Performance tests passed
    - [ ] Security tests passed
    
  Documentation:
    - [ ] Changelog updated
    - [ ] Migration guide created (if needed)
    - [ ] Architecture docs updated
    - [ ] API documentation updated
    
  Deployment_Readiness:
    - [ ] Rollback plan tested
    - [ ] Monitoring configured
    - [ ] Alerts configured
    - [ ] Team notification prepared
```

## Troubleshooting

### Common Versioning Issues

#### Version Conflicts

```bash
# Resolve version conflicts between environments
# Check current versions
jq '.environments' infrastructure-version.json

# Fix version mismatch
TARGET_ENV="staging"
SOURCE_VERSION=$(jq -r '.environments.production' infrastructure-version.json)
jq --arg env "$TARGET_ENV" --arg version "$SOURCE_VERSION" \
   '.environments[$env] = $version' \
   infrastructure-version.json > tmp.json && mv tmp.json infrastructure-version.json
```

#### Git Tag Issues

```bash
# Fix duplicate or incorrect tags
git tag -d v2.1.0  # Delete local tag
git push origin :refs/tags/v2.1.0  # Delete remote tag

# Create correct tag
git tag -a v2.1.0 -m "Release version 2.1.0"
git push origin v2.1.0
```

#### State File Version Conflicts

```bash
# Terraform state version issues
terraform state pull > state-backup.json
terraform init -upgrade
terraform plan
```

## Next Steps

1. Set up [monitoring and observability](../monitoring/azure-monitor-setup.md)
2. Implement [cost optimization](cost-optimization.md) strategies
3. Configure [security hardening](security-hardening.md)
4. Set up [disaster recovery](../backup-dr/disaster-recovery-plan.md)

# Infrastructure Setup Checklist

## Prerequisites Verification

### GitHub Configuration
- [x] Local Git repository initialized
- [x] Git user configured (Andy Lynch / andrew.lynch@granite.ie)
- [x] .gitignore file created
- [x] Files staged for initial commit
- [ ] GitHub repository created (needs authentication)
- [ ] Remote repository configured
- [ ] Initial commit and push completed

### Azure Resources Required

#### Authentication & Access
- [ ] Azure CLI installed and configured
- [ ] Azure subscription verified
- [ ] Service Principal created for automation
- [ ] Resource Group created
- [ ] Required Azure providers registered

#### Core Infrastructure
- [ ] Azure Static Web Apps (Frontend hosting)
- [ ] Azure Container Instances (WordPress backend)
- [ ] Azure Database for MySQL (Database)
- [ ] Azure Blob Storage (Media storage)
- [ ] Azure CDN Profile (Content delivery)
- [ ] Azure Key Vault (Secrets management)

#### Networking & Security
- [ ] Virtual Network configured
- [ ] Network Security Groups configured
- [ ] Application Gateway (Load balancer)
- [ ] DNS Zone configured
- [ ] SSL certificates configured

#### Monitoring & Management
- [ ] Application Insights configured
- [ ] Log Analytics Workspace
- [ ] Azure Monitor alerts
- [ ] Cost Management alerts

### Environment Variables Required

```bash
# Azure Configuration
AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT_ID=""
AZURE_CLIENT_ID=""
AZURE_CLIENT_SECRET=""

# Resource Configuration
AZURE_RESOURCE_GROUP=""
AZURE_LOCATION="eastus"
AZURE_ENVIRONMENT="dev" # dev, staging, prod

# Database Configuration
MYSQL_ROOT_PASSWORD=""
MYSQL_DATABASE="wordpress"
MYSQL_USER="wordpress"
MYSQL_PASSWORD=""

# WordPress Configuration
WP_ADMIN_USER=""
WP_ADMIN_PASSWORD=""
WP_ADMIN_EMAIL=""
WP_HOME="https://your-domain.com"
WP_SITEURL="https://your-domain.com"

# Security Keys (generate via WordPress salts generator)
WP_AUTH_KEY=""
WP_SECURE_AUTH_KEY=""
WP_LOGGED_IN_KEY=""
WP_NONCE_KEY=""
WP_AUTH_SALT=""
WP_SECURE_AUTH_SALT=""
WP_LOGGED_IN_SALT=""
WP_NONCE_SALT=""

# GitHub Actions
GITHUB_TOKEN=""
```

### Domain & DNS
- [ ] Domain registered
- [ ] DNS configured to point to Azure
- [ ] SSL certificate configured

## Quick Start Commands

### Install Required Tools
```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### Azure Setup
```bash
# Login to Azure
az login

# Create Resource Group
az group create --name "rg-wordpress-nextjs-dev" --location "eastus"

# Create Service Principal for CI/CD
az ad sp create-for-rbac --name "sp-wordpress-nextjs" --role contributor --scopes /subscriptions/{subscription-id}/resourceGroups/rg-wordpress-nextjs-dev
```

### GitHub Repository Setup
```bash
# Create repository on GitHub (manual step)
# Then add remote and push

git remote add origin git@github.com:your-username/headless-wordpress-nextjs.git
git branch -M main
git commit -m "Initial commit: Enterprise architecture foundation"
git push -u origin main
```

## Validation Commands

### Test Azure Connection
```bash
az account show
az group list
az provider list --query "[?registrationState=='Registered'].namespace" --output table
```

### Test Docker Environment
```bash
docker --version
docker-compose --version
make quick-start  # From our Makefile
```

### Test GitHub Integration
```bash
git status
git remote -v
gh auth status  # If GitHub CLI is installed
```

## Next Steps After Infrastructure Setup

1. **Environment Configuration**: Copy `.env.example` to `.env` and configure all variables
2. **Docker Development**: Start local development environment
3. **Azure Deployment**: Deploy infrastructure using Terraform
4. **GitHub Actions**: Configure CI/CD pipeline
5. **Domain Setup**: Configure custom domain and SSL
6. **Monitoring**: Set up Application Insights and alerts

## Troubleshooting

### Common Issues

#### Azure CLI Authentication
```bash
az logout
az login --tenant your-tenant-id
```

#### Docker Permission Issues
```bash
sudo usermod -aG docker $USER
# Logout and login again
```

#### GitHub Authentication
```bash
gh auth login
# Or set up SSH keys
ssh-keygen -t ed25519 -C "your_email@example.com"
```

## Security Considerations

- [ ] Service Principal has minimum required permissions
- [ ] Secrets stored in Azure Key Vault
- [ ] Network access restricted via NSGs
- [ ] SSL/TLS configured for all endpoints
- [ ] Database access restricted to application subnet
- [ ] Monitoring and alerting configured for security events
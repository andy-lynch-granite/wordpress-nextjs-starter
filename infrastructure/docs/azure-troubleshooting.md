# Azure Static Website Deployment Troubleshooting

This guide helps debug and resolve common issues with Azure Storage static website deployment.

## Quick Diagnosis

### 1. Check Site Status
```bash
curl -I https://wordpressnextjsdevstatic.z16.web.core.windows.net/
```

### 2. Test Deployment Script
```bash
cd infrastructure/scripts
chmod +x test-azure-deployment.sh
./test-azure-deployment.sh
```

## Common Issues and Solutions

### Issue: 404 WebContentNotFound

**Symptoms:**
- Site returns 404 error
- Error: "WebContentNotFound - The requested content does not exist"

**Possible Causes:**
1. Static website hosting not enabled
2. Files not uploaded to `$web` container
3. Index document not set correctly
4. Permissions issues

**Solutions:**

#### 1. Enable Static Website Hosting
```bash
az storage blob service-properties update \
  --account-name wordpressnextjsdevstatic \
  --static-website \
  --index-document index.html \
  --404-document 404.html \
  --auth-mode login
```

#### 2. Verify Files Are Uploaded
```bash
# List files in $web container
az storage blob list \
  --account-name wordpressnextjsdevstatic \
  --container-name '$web' \
  --auth-mode login \
  --output table
```

#### 3. Check index.html Exists
```bash
az storage blob show \
  --account-name wordpressnextjsdevstatic \
  --container-name '$web' \
  --name index.html \
  --auth-mode login
```

### Issue: GitHub Actions Deployment Fails

**Check Workflow Logs:**
1. Go to GitHub Actions tab
2. Click on the failed workflow run
3. Expand the "Deploy to Azure Storage" step

**Common Fixes:**

#### 1. Authentication Issues
Verify GitHub secrets are set correctly:
- `AZURE_CREDENTIALS`
- `DEV_STORAGE_ACCOUNT`
- `DEV_RESOURCE_GROUP`
- `DEV_DOMAIN_NAME`

#### 2. Permissions Issues
Ensure service principal has the correct role:
```bash
az role assignment create \
  --assignee <service-principal-id> \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/wordpressnextjs-dev-rg/providers/Microsoft.Storage/storageAccounts/wordpressnextjsdevstatic"
```

### Issue: Static Assets Not Loading

**Symptoms:**
- Site loads but CSS/JS files return 404
- Styling is broken

**Solution:**
Ensure all `_next/` static files are uploaded:
```bash
# Check _next directory structure
az storage blob list \
  --account-name wordpressnextjsdevstatic \
  --container-name '$web' \
  --prefix '_next/' \
  --auth-mode login
```

### Issue: Caching Problems

**Symptoms:**
- Old content still showing
- Changes not reflected

**Solutions:**
1. Clear browser cache (Ctrl+F5)
2. Wait for Azure CDN propagation (up to 10 minutes)
3. Force refresh Azure CDN:
```bash
az cdn endpoint purge \
  --resource-group wordpressnextjs-dev-rg \
  --profile-name <cdn-profile-name> \
  --name <endpoint-name> \
  --content-paths "/*"
```

## Manual Deployment Steps

If GitHub Actions fails, deploy manually:

### 1. Build Next.js Application
```bash
cd frontend
npm ci
npm run build
```

### 2. Upload to Azure Storage
```bash
az storage blob upload-batch \
  --account-name wordpressnextjsdevstatic \
  --destination '$web' \
  --source out \
  --overwrite \
  --auth-mode login
```

### 3. Verify Deployment
```bash
curl -I https://wordpressnextjsdevstatic.z16.web.core.windows.net/
```

## Azure Portal Verification

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to Storage Account: `wordpressnextjsdevstatic`
3. Click "Static website" in the left menu
4. Verify:
   - Static website hosting is "Enabled"
   - Index document name is "index.html"
   - Error document path is "404.html"
   - Primary endpoint shows the correct URL

## Useful Commands

### Check Storage Account Details
```bash
az storage account show \
  --name wordpressnextjsdevstatic \
  --resource-group wordpressnextjs-dev-rg
```

### Get Static Website Configuration
```bash
az storage blob service-properties show \
  --account-name wordpressnextjsdevstatic \
  --auth-mode login \
  --query staticWebsite
```

### Download a File for Verification
```bash
az storage blob download \
  --account-name wordpressnextjsdevstatic \
  --container-name '$web' \
  --name index.html \
  --file local-index.html \
  --auth-mode login
```

## Environment URLs

- **Development**: https://wordpressnextjsdevstatic.z16.web.core.windows.net/
- **Production**: TBD
- **Preview**: TBD

## Support Resources

- [Azure Static Website Documentation](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website)
- [Next.js Static Export Documentation](https://nextjs.org/docs/app/building-your-application/deploying/static-exports)
- [GitHub Actions Azure Login](https://github.com/marketplace/actions/azure-login)
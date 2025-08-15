# WordPress Pipeline Debugging Guide

## Most Likely Failure Points:

### 1. **Azure Container App Exec Issues**
The `az containerapp exec` command often fails due to:
- **TTY/Interactive mode**: Container exec expects interactive terminal
- **Permissions**: Service principal may lack Container App execution permissions
- **Container state**: Container might be restarting or unavailable

**Solution**: Replace `az containerapp exec` with `az containerapp update` for configuration changes

### 2. **Service Principal Permissions**
Current permissions might be missing:
- `Microsoft.App/containerApps/exec/action` (for container exec)
- `Microsoft.App/containerApps/write` (for updates)

### 3. **WP-CLI Installation**
The workflow tries to install WP-CLI which might fail due to:
- Missing PHP in GitHub Actions runner
- Network issues downloading WP-CLI
- Permission issues with installer

### 4. **Environment Variable Names**
The environment detection might be using wrong variable names or formats.

## Quick Fix Strategy:

1. **Check GitHub Actions Logs**:
   - Go to: https://github.com/andy-lynch-granite/wordpress-nextjs-starter/actions
   - Click on the failed "Deploy WordPress Backend (Simple)" run
   - Expand the failed step to see exact error message

2. **Common Error Patterns**:
   - `TTY allocation`: Container exec failing due to non-interactive mode
   - `Permission denied`: Service principal lacks permissions
   - `Container not found`: Wrong container name or resource group
   - `Command not found`: Missing tools in container or runner

3. **Immediate Fixes**:
   - Remove `az containerapp exec` commands
   - Focus on environment variable updates only
   - Add better error handling and logging

## Updated Workflow Strategy:
Instead of file deployment via exec, update to:
1. Just update environment variables to track deployments
2. Use volume mounts or container image updates for file deployment
3. Add webhook notifications to WordPress for reloading
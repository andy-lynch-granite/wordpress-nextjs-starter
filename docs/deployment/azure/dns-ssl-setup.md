# DNS and SSL Configuration Guide

This guide provides comprehensive instructions for setting up custom domains, DNS configuration, and SSL certificates for your headless WordPress + Next.js application on Azure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Domain Registration and Management](#domain-registration-and-management)
3. [Azure DNS Zone Configuration](#azure-dns-zone-configuration)
4. [SSL Certificate Management](#ssl-certificate-management)
5. [Application Gateway SSL Termination](#application-gateway-ssl-termination)
6. [CDN SSL Configuration](#cdn-ssl-configuration)
7. [Subdomain Configuration](#subdomain-configuration)
8. [Security Headers](#security-headers)
9. [Monitoring and Validation](#monitoring-and-validation)
10. [Troubleshooting](#troubleshooting)

## Prerequisites

- Active Azure subscription with appropriate permissions
- Domain name registered with a domain registrar
- Azure CLI installed and configured
- Basic understanding of DNS concepts

## Domain Registration and Management

### Recommended Domain Registrars

```bash
# Popular domain registrars with good Azure integration
- Namecheap
- GoDaddy
- Google Domains
- Cloudflare Registrar
```

### Domain Planning

```yaml
# Example domain structure
Primary Domain: example.com
WWW Redirect: www.example.com -> example.com
API Subdomain: api.example.com
CMS Subdomain: cms.example.com
Staging: staging.example.com
Development: dev.example.com
```

## Azure DNS Zone Configuration

### Create DNS Zone

```bash
# Create resource group for DNS (if not exists)
az group create \
  --name rg-dns-prod \
  --location eastus

# Create DNS zone
az network dns zone create \
  --resource-group rg-dns-prod \
  --name example.com

# Get name servers
az network dns zone show \
  --resource-group rg-dns-prod \
  --name example.com \
  --query nameServers
```

### Configure Name Servers at Registrar

```text
# Update name servers at your domain registrar with Azure DNS name servers
# Example Azure DNS name servers:
ns1-01.azure-dns.com
ns2-01.azure-dns.net
ns3-01.azure-dns.org
ns4-01.azure-dns.info
```

### DNS Record Configuration

```bash
# A record for root domain (pointing to Application Gateway)
az network dns record-set a add-record \
  --resource-group rg-dns-prod \
  --zone-name example.com \
  --record-set-name @ \
  --ipv4-address <APPLICATION_GATEWAY_IP>

# CNAME for www subdomain
az network dns record-set cname set-record \
  --resource-group rg-dns-prod \
  --zone-name example.com \
  --record-set-name www \
  --cname example.com

# A record for API subdomain
az network dns record-set a add-record \
  --resource-group rg-dns-prod \
  --zone-name example.com \
  --record-set-name api \
  --ipv4-address <APPLICATION_GATEWAY_IP>

# A record for CMS subdomain
az network dns record-set a add-record \
  --resource-group rg-dns-prod \
  --zone-name example.com \
  --record-set-name cms \
  --ipv4-address <APPLICATION_GATEWAY_IP>
```

## SSL Certificate Management

### Azure Key Vault Setup

```bash
# Create Key Vault for certificate storage
az keyvault create \
  --name kv-ssl-prod-<unique-suffix> \
  --resource-group rg-ssl-prod \
  --location eastus \
  --enable-soft-delete true \
  --enable-purge-protection true

# Configure access policies
az keyvault set-policy \
  --name kv-ssl-prod-<unique-suffix> \
  --object-id <SERVICE_PRINCIPAL_OBJECT_ID> \
  --certificate-permissions get list create update import delete \
  --secret-permissions get list set delete
```

### SSL Certificate Options

#### Option 1: Azure Managed Certificates (Recommended)

```bash
# Create managed certificate for Application Gateway
az network application-gateway ssl-cert create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name ssl-example-com \
  --key-vault-secret-id https://kv-ssl-prod-<suffix>.vault.azure.net/certificates/example-com
```

#### Option 2: Let's Encrypt with Azure Automation

```powershell
# PowerShell script for Let's Encrypt automation
# Install required modules
Install-Module -Name Posh-ACME
Install-Module -Name Az.KeyVault

# Configure Let's Encrypt
Set-PAServer LE_PROD

# Request certificate
$cert = New-PACertificate -Domain 'example.com','www.example.com' -AcceptTOS -Contact 'admin@example.com'

# Upload to Key Vault
$certBytes = [System.IO.File]::ReadAllBytes($cert.PfxFile)
$certPassword = ConvertTo-SecureString -String $cert.PfxPass -AsPlainText -Force
Import-AzKeyVaultCertificate -VaultName 'kv-ssl-prod-<suffix>' -Name 'example-com' -CertificateData $certBytes -Password $certPassword
```

#### Option 3: Commercial SSL Certificate

```bash
# Upload commercial certificate to Key Vault
az keyvault certificate import \
  --vault-name kv-ssl-prod-<unique-suffix> \
  --name example-com \
  --file /path/to/certificate.pfx \
  --password <CERTIFICATE_PASSWORD>
```

## Application Gateway SSL Termination

### Configure HTTPS Listeners

```bash
# Create HTTPS listener for root domain
az network application-gateway http-listener create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name listener-https-root \
  --frontend-port port-443 \
  --protocol Https \
  --ssl-cert ssl-example-com \
  --host-name example.com

# Create HTTPS listener for www subdomain
az network application-gateway http-listener create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name listener-https-www \
  --frontend-port port-443 \
  --protocol Https \
  --ssl-cert ssl-example-com \
  --host-name www.example.com

# Create HTTPS listener for API subdomain
az network application-gateway http-listener create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name listener-https-api \
  --frontend-port port-443 \
  --protocol Https \
  --ssl-cert ssl-example-com \
  --host-name api.example.com
```

### Configure Routing Rules

```bash
# Create routing rule for root domain
az network application-gateway rule create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name rule-https-root \
  --http-listener listener-https-root \
  --rule-type Basic \
  --address-pool pool-nextjs \
  --http-settings settings-nextjs

# Create routing rule for API subdomain
az network application-gateway rule create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name rule-https-api \
  --http-listener listener-https-api \
  --rule-type Basic \
  --address-pool pool-wordpress \
  --http-settings settings-wordpress
```

### HTTP to HTTPS Redirection

```bash
# Create redirect configuration
az network application-gateway redirect-config create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name redirect-http-to-https \
  --type Permanent \
  --target-listener listener-https-root \
  --include-path true \
  --include-query-string true

# Create HTTP listener for redirection
az network application-gateway http-listener create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name listener-http-redirect \
  --frontend-port port-80 \
  --protocol Http

# Create redirection rule
az network application-gateway rule create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name rule-http-redirect \
  --http-listener listener-http-redirect \
  --rule-type Basic \
  --redirect-config redirect-http-to-https
```

## CDN SSL Configuration

### Azure CDN SSL Setup

```bash
# Enable HTTPS on CDN endpoint
az cdn endpoint update \
  --name cdn-wordpress-prod \
  --profile-name cdnprofile-wordpress-prod \
  --resource-group rg-cdn-prod \
  --https-redirect Enabled \
  --minimum-tls-version '1.2'

# Configure custom domain for CDN
az cdn custom-domain create \
  --endpoint-name cdn-wordpress-prod \
  --profile-name cdnprofile-wordpress-prod \
  --resource-group rg-cdn-prod \
  --name cdn-example-com \
  --hostname cdn.example.com

# Enable HTTPS for custom domain
az cdn custom-domain enable-https \
  --endpoint-name cdn-wordpress-prod \
  --profile-name cdnprofile-wordpress-prod \
  --resource-group rg-cdn-prod \
  --name cdn-example-com \
  --certificate-source Cdn
```

## Subdomain Configuration

### Environment-Specific Subdomains

```yaml
# DNS Records for Different Environments
Production:
  - example.com (root domain)
  - www.example.com (www redirect)
  - api.example.com (WordPress GraphQL)
  - cdn.example.com (CDN assets)

Staging:
  - staging.example.com
  - api-staging.example.com
  - cdn-staging.example.com

Development:
  - dev.example.com
  - api-dev.example.com
```

### Wildcard SSL Certificate

```bash
# Request wildcard certificate for subdomains
# This requires DNS validation
az keyvault certificate create \
  --vault-name kv-ssl-prod-<unique-suffix> \
  --name wildcard-example-com \
  --policy '{"issuerParameters":{"name":"DigiCert"}, "keyProperties":{"keyType":"RSA", "keySize":2048}, "subjectAlternativeNames":{"dnsNames":["*.example.com", "example.com"]}}'
```

## Security Headers

### Application Gateway Security Headers

```bash
# Create custom probe with security headers
az network application-gateway probe create \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name probe-secure \
  --protocol Https \
  --host-name-from-http-settings true \
  --path / \
  --interval 30 \
  --timeout 30 \
  --threshold 3

# Update HTTP settings to include security headers
az network application-gateway http-settings update \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name settings-nextjs \
  --probe probe-secure \
  --protocol Https \
  --port 443 \
  --cookie-based-affinity Disabled
```

### WAF Security Rules

```bash
# Create WAF policy with SSL/TLS security
az network application-gateway waf-policy create \
  --name wafpolicy-wordpress-prod \
  --resource-group rg-app-prod \
  --location eastus

# Configure TLS policy
az network application-gateway waf-policy policy-setting update \
  --policy-name wafpolicy-wordpress-prod \
  --resource-group rg-app-prod \
  --mode Prevention \
  --state Enabled \
  --max-request-body-size-kb 128 \
  --file-upload-limit-mb 100
```

## Monitoring and Validation

### SSL Certificate Monitoring

```bash
# Create alert for certificate expiration
az monitor metrics alert create \
  --name alert-ssl-expiration \
  --resource-group rg-monitoring-prod \
  --scopes /subscriptions/<subscription-id>/resourceGroups/rg-app-prod/providers/Microsoft.Network/applicationGateways/ag-wordpress-prod \
  --condition "avg 'Certificate Expiry Days' < 30" \
  --description "SSL certificate expires in less than 30 days" \
  --evaluation-frequency 1d \
  --window-size 1d \
  --severity 2
```

### SSL Health Checks

```bash
#!/bin/bash
# SSL validation script

DOMAINS=("example.com" "www.example.com" "api.example.com")

for domain in "${DOMAINS[@]}"; do
    echo "Checking SSL for $domain..."
    
    # Check certificate expiration
    expiry=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    echo "Certificate expires: $expiry"
    
    # Check SSL Labs rating
    curl -s "https://api.ssllabs.com/api/v3/analyze?host=$domain&publish=off&startNew=off&all=done" | jq '.endpoints[0].grade'
    
    echo "---"
done
```

### DNS Propagation Check

```bash
#!/bin/bash
# DNS propagation validation

DOMAIN="example.com"
EXPECTED_IP="<APPLICATION_GATEWAY_IP>"

# Check DNS resolution from multiple locations
DNS_SERVERS=("8.8.8.8" "1.1.1.1" "208.67.222.222")

for dns in "${DNS_SERVERS[@]}"; do
    echo "Checking DNS resolution via $dns..."
    resolved_ip=$(dig @$dns $DOMAIN +short)
    
    if [ "$resolved_ip" = "$EXPECTED_IP" ]; then
        echo "✓ $DOMAIN resolves correctly to $resolved_ip"
    else
        echo "✗ $DOMAIN resolves to $resolved_ip (expected $EXPECTED_IP)"
    fi
done
```

## Troubleshooting

### Common SSL Issues

#### Certificate Not Trusted

```bash
# Check certificate chain
openssl s_client -servername example.com -connect example.com:443 -showcerts

# Verify certificate in Key Vault
az keyvault certificate show \
  --vault-name kv-ssl-prod-<unique-suffix> \
  --name example-com
```

#### Mixed Content Warnings

```javascript
// Ensure all resources use HTTPS in Next.js
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: "upgrade-insecure-requests"
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=31536000; includeSubDomains'
          }
        ]
      }
    ]
  }
}
```

#### DNS Resolution Issues

```bash
# Clear DNS cache
sudo systemctl flush-dns  # Linux
sudo dscacheutil -flushcache  # macOS
ipconfig /flushdns  # Windows

# Check TTL values
dig example.com

# Test with different DNS servers
nslookup example.com 8.8.8.8
```

### Certificate Renewal Issues

```bash
# Check certificate status in Key Vault
az keyvault certificate show \
  --vault-name kv-ssl-prod-<unique-suffix> \
  --name example-com \
  --query 'attributes.expires'

# Manual certificate renewal (Let's Encrypt)
Set-PACertificate -MainDomain 'example.com' -Force

# Update Application Gateway with new certificate
az network application-gateway ssl-cert update \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --name ssl-example-com \
  --key-vault-secret-id https://kv-ssl-prod-<suffix>.vault.azure.net/certificates/example-com
```

### Performance Optimization

```bash
# Enable HTTP/2
az network application-gateway http2 enable \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod

# Configure SSL caching
az network application-gateway ssl-policy set \
  --gateway-name ag-wordpress-prod \
  --resource-group rg-app-prod \
  --policy-type Predefined \
  --policy-name AppGwSslPolicy20220101
```

## Security Best Practices

1. **Use TLS 1.2 or higher** for all SSL connections
2. **Implement HSTS** headers for secure transport
3. **Use strong cipher suites** in SSL policies
4. **Regular certificate rotation** (every 90 days for Let's Encrypt)
5. **Monitor certificate expiration** with automated alerts
6. **Implement CAA records** for certificate authority authorization
7. **Use OCSP stapling** for certificate revocation checking
8. **Configure security headers** (CSP, HSTS, X-Frame-Options)

## Cost Optimization

- Use **Azure Managed Certificates** when possible (free)
- Implement **wildcard certificates** for multiple subdomains
- Configure **appropriate TTL values** for DNS records
- Use **Azure CDN** for SSL termination at edge locations
- Monitor **Application Gateway pricing** tiers based on traffic

## Next Steps

1. Configure [scaling and performance optimization](scaling-configuration.md)
2. Set up [monitoring and alerting](../monitoring/azure-monitor-setup.md)
3. Implement [backup and disaster recovery](../backup-dr/backup-strategy.md)
4. Review [security hardening checklist](../infrastructure/security-hardening.md)

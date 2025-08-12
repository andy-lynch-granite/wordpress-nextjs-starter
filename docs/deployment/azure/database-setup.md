# Database Setup and Optimization Guide

This guide covers advanced database configuration, optimization, backup strategies, and maintenance procedures for the Azure MySQL Flexible Server in the headless WordPress solution.

## Prerequisites

- Azure MySQL Flexible Server created ([Azure Setup Guide](./azure-setup-guide.md))
- WordPress container deployed ([WebApp Deployment Guide](./webapp-deployment.md))
- Database admin credentials stored in Key Vault

## Database Architecture

```
┌───────────────────────┐
│   WordPress Container      │
│                          │
│   ┌──────────────────┐   │
│   │   Connection Pool    │   │
│   │   (wp-config.php)    │   │
│   └──────────────────┘   │
└───────────────────────┘
                  │
                  ▼ SSL/TLS
┌───────────────────────┐
│   Azure MySQL Flexible     │
│                          │
│   ┌──────────────────┐   │
│   │   wordpress (DB)     │   │
│   │   - wp_posts         │   │
│   │   - wp_postmeta      │   │
│   │   - wp_users         │   │
│   │   - wp_options       │   │
│   │   - Custom tables    │   │
│   └──────────────────┘   │
│                          │
│   ┌──────────────────┐   │
│   │   Automated Backup   │   │
│   │   Point-in-time      │   │
│   │   Recovery           │   │
│   └──────────────────┘   │
└───────────────────────┘
                  │
                  ▼
┌───────────────────────┐
│   Redis Cache              │
│   (Object Cache)           │
└───────────────────────┘
```

## Step 1: Environment Setup

```bash
# Source environment variables
source .env.azure

# Get database credentials
export MYSQL_HOST="${MYSQL_SERVER_NAME}.mysql.database.azure.com"
export MYSQL_USERNAME=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name "mysql-admin-username" \
  --query value -o tsv)
export MYSQL_PASSWORD=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name "mysql-admin-password" \
  --query value -o tsv)
```

## Step 2: Advanced Database Configuration

### 2.1 WordPress-Optimized Parameters

```bash
# Configure MySQL parameters for WordPress optimization
echo "Configuring MySQL parameters for WordPress..."

# InnoDB Buffer Pool (adjust based on server size)
# For Burstable B2s (4GB RAM): 1.5GB buffer pool
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name innodb_buffer_pool_size \
  --value 1610612736  # 1.5GB in bytes

# Query Cache (disabled by default in MySQL 8.0, but set query cache type)
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name query_cache_type \
  --value 0

# Max connections
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name max_connections \
  --value 200

# WordPress specific settings
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name max_allowed_packet \
  --value 67108864  # 64MB

# Connection timeout
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name wait_timeout \
  --value 600  # 10 minutes

# Interactive timeout
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name interactive_timeout \
  --value 600  # 10 minutes

# Table cache
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name table_open_cache \
  --value 4000

# Sort buffer
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name sort_buffer_size \
  --value 2097152  # 2MB

# Read buffer
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name read_buffer_size \
  --value 131072  # 128KB

# Slow query log
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name slow_query_log \
  --value ON

az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name long_query_time \
  --value 2.0
```

### 2.2 SSL/TLS Configuration

```bash
# Verify SSL is enabled
az mysql flexible-server parameter show \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name require_secure_transport

# Download SSL certificate
mkdir -p ssl-certs
wget -O ssl-certs/DigiCertGlobalRootCA.crt.pem \
  https://www.digicert.com/CACerts/DigiCertGlobalRootCA.crt

# Test SSL connection
mysql --host=$MYSQL_HOST \
      --user=$MYSQL_USERNAME \
      --password=$MYSQL_PASSWORD \
      --ssl-mode=REQUIRED \
      --ssl-ca=ssl-certs/DigiCertGlobalRootCA.crt.pem \
      --execute="SHOW STATUS LIKE 'Ssl_cipher';"
```

## Step 3: Database Schema Optimization

### 3.1 WordPress Schema Analysis

Create a database analysis script:

```bash
cat > analyze-database.sql << 'EOF'
-- Database analysis queries for WordPress optimization

-- Check table sizes
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)',
    table_rows AS 'Rows'
FROM information_schema.tables 
WHERE table_schema = 'wordpress'
ORDER BY (data_length + index_length) DESC;

-- Check for missing indexes on large tables
SELECT 
    table_name,
    column_name,
    cardinality,
    sub_part,
    nullable
FROM information_schema.statistics 
WHERE table_schema = 'wordpress' 
AND table_name IN ('wp_posts', 'wp_postmeta', 'wp_comments', 'wp_options')
ORDER BY table_name, seq_in_index;

-- Check wp_options autoload
SELECT 
    autoload,
    COUNT(*) as count,
    SUM(LENGTH(option_value)) as total_size
FROM wp_options 
GROUP BY autoload;

-- Find large autoloaded options
SELECT 
    option_name,
    LENGTH(option_value) as size,
    autoload
FROM wp_options 
WHERE autoload = 'yes' 
AND LENGTH(option_value) > 1000
ORDER BY size DESC
LIMIT 20;

-- Check for revision buildup
SELECT 
    post_type,
    COUNT(*) as count
FROM wp_posts 
WHERE post_type IN ('revision', 'auto-draft', 'trash')
GROUP BY post_type;
EOF

# Run analysis
mysql --host=$MYSQL_HOST \
      --user=$MYSQL_USERNAME \
      --password=$MYSQL_PASSWORD \
      --ssl-mode=REQUIRED \
      --database=$MYSQL_DATABASE \
      < analyze-database.sql > database-analysis.txt

echo "Database analysis saved to database-analysis.txt"
```

### 3.2 WordPress-Specific Indexes

```bash
cat > optimize-wordpress-indexes.sql << 'EOF'
-- WordPress performance indexes

-- Posts table optimization
ALTER TABLE wp_posts ADD INDEX idx_post_name (post_name);
ALTER TABLE wp_posts ADD INDEX idx_post_author (post_author);
ALTER TABLE wp_posts ADD INDEX idx_post_parent (post_parent);
ALTER TABLE wp_posts ADD INDEX idx_post_type_status_date (post_type, post_status, post_date);

-- Postmeta table optimization  
ALTER TABLE wp_postmeta ADD INDEX idx_meta_key_value (meta_key(20), meta_value(20));
ALTER TABLE wp_postmeta ADD INDEX idx_meta_key (meta_key);

-- Comments optimization
ALTER TABLE wp_comments ADD INDEX idx_comment_approved_date (comment_approved, comment_date_gmt);
ALTER TABLE wp_comments ADD INDEX idx_comment_post_id (comment_post_ID);

-- Options table optimization
ALTER TABLE wp_options ADD INDEX idx_autoload (autoload);

-- User meta optimization
ALTER TABLE wp_usermeta ADD INDEX idx_user_meta_key (user_id, meta_key(20));

-- Term relationships
ALTER TABLE wp_term_relationships ADD INDEX idx_term_taxonomy_id (term_taxonomy_id);

-- Show index status
SHOW INDEX FROM wp_posts;
SHOW INDEX FROM wp_postmeta;
EOF

# Apply optimizations (run during maintenance window)
# mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --database=$MYSQL_DATABASE < optimize-wordpress-indexes.sql
```

## Step 4: Backup and Recovery Configuration

### 4.1 Automated Backup Configuration

```bash
# Configure backup retention and frequency
az mysql flexible-server update \
  --resource-group $RESOURCE_GROUP \
  --name $MYSQL_SERVER_NAME \
  --backup-retention 30 \
  --geo-redundant-backup Enabled

# Verify backup configuration
az mysql flexible-server show \
  --resource-group $RESOURCE_GROUP \
  --name $MYSQL_SERVER_NAME \
  --query '{name:name, backupRetentionDays:backup.backupRetentionDays, geoRedundantBackup:backup.geoRedundantBackup}'
```

### 4.2 Manual Backup Scripts

```bash
cat > backup-database.sh << 'EOF'
#!/bin/bash

# Manual database backup script
set -e

# Configuration
BACKUP_DIR="./database-backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="wordpress_backup_${DATE}.sql"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

# Create backup directory
mkdir -p $BACKUP_DIR

echo "Starting database backup..."

# Create backup
mysqldump --host=$MYSQL_HOST \
          --user=$MYSQL_USERNAME \
          --password=$MYSQL_PASSWORD \
          --ssl-mode=REQUIRED \
          --single-transaction \
          --routines \
          --triggers \
          --databases $MYSQL_DATABASE > $BACKUP_DIR/$BACKUP_FILE

# Compress backup
gzip $BACKUP_DIR/$BACKUP_FILE

echo "Backup completed: $BACKUP_DIR/$COMPRESSED_FILE"

# Upload to Azure Storage (optional)
if [ ! -z "$AZURE_STORAGE_ACCOUNT" ]; then
    az storage blob upload \
        --account-name $AZURE_STORAGE_ACCOUNT \
        --container-name database-backups \
        --name $COMPRESSED_FILE \
        --file $BACKUP_DIR/$COMPRESSED_FILE
    
    echo "Backup uploaded to Azure Storage"
fi

# Cleanup old backups (keep last 7 days locally)
find $BACKUP_DIR -name "wordpress_backup_*.sql.gz" -mtime +7 -delete

echo "Backup process completed successfully"
EOF

chmod +x backup-database.sh
```

### 4.3 Point-in-Time Recovery Setup

```bash
# Create point-in-time recovery script
cat > restore-database.sh << 'EOF'
#!/bin/bash

# Point-in-time recovery script
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <restore-time> [new-server-name]"
    echo "Example: $0 '2023-12-01T10:30:00Z'"
    exit 1
fi

RESTORE_TIME=$1
NEW_SERVER_NAME=${2:-"${MYSQL_SERVER_NAME}-restored-$(date +%s)"}

echo "Creating point-in-time restore to: $NEW_SERVER_NAME"
echo "Restore time: $RESTORE_TIME"

# Create restored server
az mysql flexible-server restore \
    --resource-group $RESOURCE_GROUP \
    --name $NEW_SERVER_NAME \
    --source-server $MYSQL_SERVER_NAME \
    --restore-time $RESTORE_TIME \
    --location "$LOCATION"

echo "Point-in-time restore completed"
echo "New server: $NEW_SERVER_NAME"
echo "Remember to update application connection strings if needed"
EOF

chmod +x restore-database.sh
```

## Step 5: Performance Monitoring and Tuning

### 5.1 Performance Monitoring Setup

```bash
# Enable performance insights
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name performance_schema \
  --value ON

# Enable slow query log for analysis
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name log_output \
  --value FILE
```

### 5.2 Performance Analysis Queries

```bash
cat > performance-analysis.sql << 'EOF'
-- Performance analysis queries

-- Top 10 slowest queries by average execution time
SELECT 
    SCHEMA_NAME,
    ROUND(AVG_TIMER_WAIT/1000000000000,6) as avg_exec_time,
    EXEC_COUNT,
    QUERY_SAMPLE_TEXT
FROM performance_schema.events_statements_summary_by_digest 
ORDER BY AVG_TIMER_WAIT DESC 
LIMIT 10;

-- Table I/O statistics
SELECT 
    OBJECT_SCHEMA,
    OBJECT_NAME,
    COUNT_READ,
    COUNT_WRITE,
    COUNT_FETCH,
    COUNT_INSERT,
    COUNT_UPDATE,
    COUNT_DELETE
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA = 'wordpress'
ORDER BY COUNT_READ DESC;

-- Index usage statistics
SELECT 
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_FETCH,
    COUNT_INSERT,
    COUNT_UPDATE,
    COUNT_DELETE
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'wordpress'
ORDER BY COUNT_FETCH DESC;

-- Connection statistics
SELECT 
    USER,
    HOST,
    CURRENT_CONNECTIONS,
    TOTAL_CONNECTIONS
FROM performance_schema.accounts
ORDER BY TOTAL_CONNECTIONS DESC;

-- Memory usage
SELECT 
    EVENT_NAME,
    CURRENT_NUMBER_OF_BYTES_USED/1024/1024 as current_mb,
    HIGH_NUMBER_OF_BYTES_USED/1024/1024 as high_mb
FROM performance_schema.memory_summary_global_by_event_name
WHERE CURRENT_NUMBER_OF_BYTES_USED > 0
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20;
EOF
```

### 5.3 Automated Performance Monitoring

```bash
cat > monitor-database.sh << 'EOF'
#!/bin/bash

# Database performance monitoring script
set -e

MONITOR_LOG="database-monitor-$(date +%Y%m%d).log"

echo "=== Database Performance Monitor - $(date) ===" >> $MONITOR_LOG

# Check connection count
CONN_COUNT=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Threads_connected'" | cut -f2)
echo "Active Connections: $CONN_COUNT" >> $MONITOR_LOG

# Check slow queries
SLOW_QUERIES=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Slow_queries'" | cut -f2)
echo "Slow Queries: $SLOW_QUERIES" >> $MONITOR_LOG

# Check buffer pool hit ratio
BUFFER_READS=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Innodb_buffer_pool_reads'" | cut -f2)
BUFFER_READ_REQUESTS=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests'" | cut -f2)

if [ $BUFFER_READ_REQUESTS -gt 0 ]; then
    HIT_RATIO=$(echo "scale=2; (1 - $BUFFER_READS / $BUFFER_READ_REQUESTS) * 100" | bc)
    echo "Buffer Pool Hit Ratio: ${HIT_RATIO}%" >> $MONITOR_LOG
fi

# Check table locks
TABLE_LOCKS_WAITED=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Table_locks_waited'" | cut -f2)
echo "Table Locks Waited: $TABLE_LOCKS_WAITED" >> $MONITOR_LOG

# Alert thresholds
if [ $CONN_COUNT -gt 150 ]; then
    echo "WARNING: High connection count ($CONN_COUNT)" >> $MONITOR_LOG
    # Add alerting logic here (email, webhook, etc.)
fi

echo "Monitor completed - $(date)" >> $MONITOR_LOG
echo "" >> $MONITOR_LOG
EOF

chmod +x monitor-database.sh

# Set up cron job for monitoring (run every 15 minutes)
echo "*/15 * * * * /path/to/monitor-database.sh" | crontab -
```

## Step 6: Database Security Hardening

### 6.1 User Management and Permissions

```bash
cat > setup-database-users.sql << 'EOF'
-- Create application-specific database users

-- WordPress application user (limited permissions)
CREATE USER 'wp_app'@'%' IDENTIFIED BY 'STRONG_PASSWORD_HERE';
GRANT SELECT, INSERT, UPDATE, DELETE ON wordpress.* TO 'wp_app'@'%';
GRANT CREATE TEMPORARY TABLES ON wordpress.* TO 'wp_app'@'%';

-- Read-only user for reporting/analytics
CREATE USER 'wp_readonly'@'%' IDENTIFIED BY 'STRONG_PASSWORD_HERE';
GRANT SELECT ON wordpress.* TO 'wp_readonly'@'%';

-- Backup user
CREATE USER 'wp_backup'@'%' IDENTIFIED BY 'STRONG_PASSWORD_HERE';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON wordpress.* TO 'wp_backup'@'%';

-- Flush privileges
FLUSH PRIVILEGES;

-- Show created users
SELECT User, Host FROM mysql.user WHERE User LIKE 'wp_%';
EOF

# Note: Replace passwords and apply during maintenance window
```

### 6.2 Audit Logging Setup

```bash
# Enable audit logging
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name audit_log_enabled \
  --value ON

az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name audit_log_events \
  --value 'CONNECTION,DML,DDL'

# Configure log retention
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name audit_log_file \
  --value 'mysql-audit.log'
```

## Step 7: WordPress Database Optimization

### 7.1 WordPress-Specific Cleanup

```bash
cat > wordpress-cleanup.sql << 'EOF'
-- WordPress database cleanup queries

-- Remove post revisions (keep last 5 per post)
DELETE r1 FROM wp_posts r1
INNER JOIN wp_posts r2 
WHERE r1.post_parent = r2.post_parent 
AND r1.post_type = 'revision' 
AND r2.post_type = 'revision'
AND r1.ID < r2.ID
AND (
  SELECT COUNT(*) FROM wp_posts r3 
  WHERE r3.post_parent = r1.post_parent 
  AND r3.post_type = 'revision' 
  AND r3.ID > r1.ID
) >= 5;

-- Remove orphaned postmeta
DELETE pm FROM wp_postmeta pm
LEFT JOIN wp_posts wp ON wp.ID = pm.post_id
WHERE wp.ID IS NULL;

-- Remove orphaned term relationships
DELETE tr FROM wp_term_relationships tr
LEFT JOIN wp_posts p ON p.ID = tr.object_id
WHERE p.ID IS NULL;

-- Remove orphaned user meta
DELETE um FROM wp_usermeta um
LEFT JOIN wp_users u ON u.ID = um.user_id
WHERE u.ID IS NULL;

-- Remove spam/trash comments and their meta
DELETE FROM wp_commentmeta WHERE comment_id IN (
  SELECT comment_ID FROM wp_comments WHERE comment_approved = 'spam' OR comment_approved = 'trash'
);
DELETE FROM wp_comments WHERE comment_approved = 'spam' OR comment_approved = 'trash';

-- Remove transients older than 24 hours
DELETE FROM wp_options WHERE option_name LIKE '_transient_%' AND option_name NOT LIKE '_transient_timeout_%';
DELETE FROM wp_options WHERE option_name LIKE '_transient_timeout_%' AND option_value < UNIX_TIMESTAMP();

-- Optimize tables
OPTIMIZE TABLE wp_posts, wp_postmeta, wp_options, wp_comments, wp_commentmeta, wp_users, wp_usermeta;
EOF

# Create automated cleanup script
cat > wordpress-maintenance.sh << 'EOF'
#!/bin/bash

# WordPress database maintenance script
set -e

echo "Starting WordPress database maintenance - $(date)"

# Run cleanup queries
mysql --host=$MYSQL_HOST \
      --user=$MYSQL_USERNAME \
      --password=$MYSQL_PASSWORD \
      --ssl-mode=REQUIRED \
      --database=$MYSQL_DATABASE \
      < wordpress-cleanup.sql

echo "WordPress database maintenance completed - $(date)"
EOF

chmod +x wordpress-maintenance.sh

# Schedule weekly maintenance (Sunday 2 AM)
# echo "0 2 * * 0 /path/to/wordpress-maintenance.sh" | crontab -
```

## Step 8: High Availability and Scaling

### 8.1 Read Replica Setup

```bash
# Create read replica for high-traffic scenarios
export REPLICA_SERVER_NAME="${MYSQL_SERVER_NAME}-replica"

# Create read replica
az mysql flexible-server replica create \
  --replica-name $REPLICA_SERVER_NAME \
  --resource-group $RESOURCE_GROUP \
  --source-server $MYSQL_SERVER_NAME \
  --location "West US 2"  # Different region for geo-redundancy

# Store replica connection details
echo "MYSQL_REPLICA_HOST=${REPLICA_SERVER_NAME}.mysql.database.azure.com" >> .env.azure
```

### 8.2 Connection Pooling Configuration

Update WordPress configuration for connection pooling:

```bash
cat > wp-config-database.php << 'EOF'
<?php
// Advanced database configuration for WordPress

// Primary database connection
define('DB_NAME', getenv('WORDPRESS_DB_NAME') ?: 'wordpress');
define('DB_USER', getenv('WORDPRESS_DB_USER'));
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD'));
define('DB_HOST', getenv('WORDPRESS_DB_HOST'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// Read replica configuration (if available)
if (getenv('MYSQL_REPLICA_HOST')) {
    define('DB_READ_HOST', getenv('MYSQL_REPLICA_HOST'));
}

// Connection pooling settings
define('WP_USE_MULTIPLE_DB', true);

// SSL configuration
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);

// Connection timeout
ini_set('mysql.connect_timeout', 60);
ini_set('default_socket_timeout', 60);

// Memory limit for large operations
ini_set('memory_limit', '512M');

// Increase max execution time for imports/exports
ini_set('max_execution_time', 300);

// WordPress-specific database optimizations
define('WP_ALLOW_REPAIR', true); // Remove after use
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_POST_REVISIONS', 5);
define('AUTOSAVE_INTERVAL', 300); // 5 minutes
define('WP_CRON_LOCK_TIMEOUT', 60);
EOF
```

## Step 9: Disaster Recovery Testing

### 9.1 DR Test Script

```bash
cat > test-disaster-recovery.sh << 'EOF'
#!/bin/bash

# Disaster recovery test script
set -e

DR_TEST_SERVER="${MYSQL_SERVER_NAME}-dr-test-$(date +%s)"
TEST_LOG="dr-test-$(date +%Y%m%d).log"

echo "Starting Disaster Recovery Test - $(date)" | tee $TEST_LOG

# Step 1: Create point-in-time restore
echo "1. Creating point-in-time restore..." | tee -a $TEST_LOG
RESTORE_TIME=$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ)

az mysql flexible-server restore \
    --resource-group $RESOURCE_GROUP \
    --name $DR_TEST_SERVER \
    --source-server $MYSQL_SERVER_NAME \
    --restore-time $RESTORE_TIME \
    --location "$LOCATION" | tee -a $TEST_LOG

# Step 2: Test connectivity
echo "2. Testing connectivity to restored server..." | tee -a $TEST_LOG
DR_HOST="${DR_TEST_SERVER}.mysql.database.azure.com"

mysql --host=$DR_HOST \
      --user=$MYSQL_USERNAME \
      --password=$MYSQL_PASSWORD \
      --ssl-mode=REQUIRED \
      --execute="SELECT COUNT(*) FROM wp_posts;" \
      $MYSQL_DATABASE | tee -a $TEST_LOG

# Step 3: Verify data integrity
echo "3. Verifying data integrity..." | tee -a $TEST_LOG
mysql --host=$DR_HOST \
      --user=$MYSQL_USERNAME \
      --password=$MYSQL_PASSWORD \
      --ssl-mode=REQUIRED \
      --database=$MYSQL_DATABASE \
      --execute="
        SELECT 
            table_name,
            table_rows,
            ROUND((data_length + index_length) / 1024 / 1024, 2) as size_mb
        FROM information_schema.tables 
        WHERE table_schema = 'wordpress' 
        ORDER BY table_rows DESC;
      " | tee -a $TEST_LOG

# Step 4: Performance test
echo "4. Running performance test..." | tee -a $TEST_LOG
START_TIME=$(date +%s)
mysql --host=$DR_HOST \
      --user=$MYSQL_USERNAME \
      --password=$MYSQL_PASSWORD \
      --ssl-mode=REQUIRED \
      --database=$MYSQL_DATABASE \
      --execute="SELECT SQL_NO_CACHE COUNT(*) FROM wp_posts WHERE post_status = 'publish';" > /dev/null
END_TIME=$(date +%s)
QUERY_TIME=$((END_TIME - START_TIME))
echo "Query execution time: ${QUERY_TIME} seconds" | tee -a $TEST_LOG

# Step 5: Cleanup test server
echo "5. Cleaning up test server..." | tee -a $TEST_LOG
az mysql flexible-server delete \
    --resource-group $RESOURCE_GROUP \
    --name $DR_TEST_SERVER \
    --yes | tee -a $TEST_LOG

echo "Disaster Recovery Test Completed - $(date)" | tee -a $TEST_LOG
echo "Results saved to: $TEST_LOG"
EOF

chmod +x test-disaster-recovery.sh
```

## Step 10: Monitoring and Alerting Integration

### 10.1 Database Metrics for Azure Monitor

```bash
# Create custom metrics collection
cat > collect-db-metrics.sh << 'EOF'
#!/bin/bash

# Collect custom database metrics for Azure Monitor
set -e

# Get Application Insights key
INSTRUMENTATION_KEY=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name "app-insights-key" \
  --query value -o tsv)

# Collect metrics
CONNECTIONS=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Threads_connected'" | cut -f2)
SLOW_QUERIES=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Slow_queries'" | cut -f2)
QPSELECT=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Com_select'" | cut -f2)
QPINSERT=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Com_insert'" | cut -f2)
QPUPDATE=$(mysql --host=$MYSQL_HOST --user=$MYSQL_USERNAME --password=$MYSQL_PASSWORD --ssl-mode=REQUIRED --skip-column-names -e "SHOW STATUS LIKE 'Com_update'" | cut -f2)

# Send to Application Insights
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

curl -X POST "https://dc.services.visualstudio.com/v2/track" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Microsoft.ApplicationInsights.MetricData\",
    \"time\": \"$TIMESTAMP\",
    \"iKey\": \"$INSTRUMENTATION_KEY\",
    \"data\": {
      \"baseType\": \"MetricData\",
      \"baseData\": {
        \"metrics\": [
          {\"name\": \"Database.Connections\", \"value\": $CONNECTIONS},
          {\"name\": \"Database.SlowQueries\", \"value\": $SLOW_QUERIES},
          {\"name\": \"Database.SelectQueries\", \"value\": $QPSELECT},
          {\"name\": \"Database.InsertQueries\", \"value\": $QPINSERT},
          {\"name\": \"Database.UpdateQueries\", \"value\": $QPUPDATE}
        ]
      }
    }
  }"
EOF

chmod +x collect-db-metrics.sh

# Schedule metrics collection (every 5 minutes)
echo "*/5 * * * * /path/to/collect-db-metrics.sh" | crontab -
```

## Summary Configuration File

```bash
# Update .env.azure with database configuration
cat >> .env.azure << EOF

# Database Configuration
MYSQL_HOST=$MYSQL_HOST
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_REPLICA_HOST=${REPLICA_SERVER_NAME:-""}.mysql.database.azure.com

# Database Backup
BACKUP_RETENTION_DAYS=30
GEO_REDUNDANT_BACKUP=true

# Performance Settings
MAX_CONNECTIONS=200
INNODB_BUFFER_POOL_SIZE=1610612736
QUERY_CACHE_SIZE=0

# Security
REQUIRE_SSL=true
AUDIT_LOG_ENABLED=true
SLOW_QUERY_LOG=true
EOF

echo "Database setup and optimization completed!"
echo "Configuration saved to .env.azure"
echo "Next steps:"
echo "1. Review and implement security hardening"
echo "2. Set up monitoring dashboards"
echo "3. Schedule regular maintenance tasks"
echo "4. Test disaster recovery procedures"
```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Connection Timeouts**
   - Increase `wait_timeout` and `interactive_timeout`
   - Check network latency between container and database
   - Verify firewall rules

2. **Slow Query Performance**
   - Enable slow query log
   - Analyze queries with EXPLAIN
   - Check for missing indexes
   - Consider query optimization

3. **High Memory Usage**
   - Adjust `innodb_buffer_pool_size`
   - Monitor `sort_buffer_size` and `read_buffer_size`
   - Check for memory leaks in WordPress plugins

4. **Lock Contentions**
   - Monitor `Table_locks_waited`
   - Consider using InnoDB instead of MyISAM
   - Optimize WordPress auto-save intervals

5. **Backup Failures**
   - Check disk space on backup storage
   - Verify backup retention policies
   - Test restore procedures regularly

### Performance Tuning Checklist

- [ ] InnoDB buffer pool optimized for available RAM
- [ ] Proper indexes on WordPress tables
- [ ] Slow query log enabled and monitored
- [ ] Connection limits appropriate for workload
- [ ] SSL/TLS properly configured
- [ ] Regular database maintenance scheduled
- [ ] Backup and recovery tested
- [ ] Monitoring and alerting configured
- [ ] Security hardening applied
- [ ] Performance baselines established

## Next Steps

1. Continue with [CDN Configuration](./cdn-configuration.md)
2. Set up [DNS and SSL](./dns-ssl-setup.md)
3. Configure [Auto-scaling](./scaling-configuration.md)
4. Implement [Monitoring Setup](../monitoring/azure-monitor-setup.md)
5. Review [Backup and DR](../backup-dr/backup-strategy.md) procedures

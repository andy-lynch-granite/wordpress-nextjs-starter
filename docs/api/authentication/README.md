# API Authentication & Security

## Overview

Our headless WordPress + Next.js platform implements multiple authentication methods to support different use cases while maintaining enterprise-grade security. This document covers all authentication methods, security procedures, and best practices.

## Authentication Methods

### 1. JWT (JSON Web Tokens) - Primary Method

JWT is our primary authentication method for API access, providing stateless, secure authentication.

#### Setup JWT Authentication

1. **Install JWT Plugin** (already configured):
   - `jwt-authentication-for-wp-rest-api`

2. **WordPress Configuration**:
   ```php
   // wp-config.php
   define('JWT_AUTH_SECRET_KEY', 'your-secret-key-here');
   define('JWT_AUTH_CORS_ENABLE', true);
   ```

3. **Environment Variables**:
   ```bash
   JWT_SECRET_KEY=your-secret-key
   JWT_EXPIRATION=7200  # 2 hours
   ```

#### Obtaining JWT Token

```http
POST /wp-json/jwt-auth/v1/token
Content-Type: application/json

{
  "username": "your-username",
  "password": "your-password"
}
```

**Response**:
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "user_email": "user@example.com",
  "user_nicename": "username",
  "user_display_name": "Display Name",
  "expires": 1640995200
}
```

#### Using JWT Token

**REST API**:
```http
GET /wp-json/wp/v2/posts
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

**GraphQL API**:
```http
POST /graphql
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
Content-Type: application/json

{
  "query": "query { posts { nodes { id title } } }"
}
```

#### Token Validation

```http
POST /wp-json/jwt-auth/v1/token/validate
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

**Valid Token Response**:
```json
{
  "code": "jwt_auth_valid_token",
  "data": {
    "status": 200
  }
}
```

#### Token Refresh

```http
POST /wp-json/jwt-auth/v1/token/refresh
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

### 2. Application Passwords

WordPress Application Passwords provide a secure way for applications to authenticate without exposing user passwords.

#### Creating Application Password

1. **Via WordPress Admin**:
   - Go to Users → Profile
   - Scroll to "Application Passwords"
   - Enter application name
   - Click "Add New Application Password"

2. **Via REST API**:
   ```http
   POST /wp-json/wp/v2/users/{user_id}/application-passwords
   Authorization: Basic base64(username:current_password)
   Content-Type: application/json

   {
     "name": "My App",
     "app_id": "my-app-id"
   }
   ```

#### Using Application Password

```http
GET /wp-json/wp/v2/posts
Authorization: Basic base64(username:application_password)
```

### 3. OAuth 2.0 Integration

For third-party applications and enterprise SSO integration.

#### OAuth Flow

1. **Authorization URL**:
   ```
   https://your-domain.com/oauth/authorize?
     response_type=code&
     client_id=your_client_id&
     redirect_uri=your_redirect_uri&
     scope=read+write&
     state=random_state_string
   ```

2. **Token Exchange**:
   ```http
   POST /wp-json/oauth/v1/token
   Content-Type: application/x-www-form-urlencoded

   grant_type=authorization_code&
   code=authorization_code&
   client_id=your_client_id&
   client_secret=your_client_secret&
   redirect_uri=your_redirect_uri
   ```

3. **Use Access Token**:
   ```http
   GET /wp-json/wp/v2/posts
   Authorization: Bearer oauth_access_token
   ```

## Security Implementation

### 1. HTTPS/TLS Configuration

**Enforce HTTPS**:
```php
// wp-config.php
define('FORCE_SSL_ADMIN', true);

// .htaccess
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

**TLS Configuration**:
```nginx
# nginx.conf
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
ssl_prefer_server_ciphers off;
```

### 2. CORS (Cross-Origin Resource Sharing)

**Development Configuration**:
```php
// functions.php
add_action('rest_api_init', function() {
    remove_filter('rest_pre_serve_request', 'rest_send_cors_headers');
    add_filter('rest_pre_serve_request', function($value) {
        header('Access-Control-Allow-Origin: http://localhost:3000');
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        header('Access-Control-Allow-Headers: Authorization, Content-Type');
        header('Access-Control-Allow-Credentials: true');
        return $value;
    });
});
```

**Production Configuration**:
```php
// Production CORS - specific domains only
header('Access-Control-Allow-Origin: https://your-production-domain.com');
```

### 3. Rate Limiting

**API Rate Limits**:
- **Authenticated**: 1000 requests/hour
- **Unauthenticated**: 100 requests/hour
- **Login attempts**: 5 attempts/15 minutes

**Implementation**:
```php
// Rate limiting middleware
add_filter('rest_request_before_callbacks', function($response, $handler, $request) {
    $client_ip = $_SERVER['REMOTE_ADDR'];
    $endpoint = $request->get_route();
    
    if (is_rate_limited($client_ip, $endpoint)) {
        return new WP_Error(
            'rate_limit_exceeded',
            'Rate limit exceeded',
            array('status' => 429)
        );
    }
    
    return $response;
}, 10, 3);
```

### 4. Input Validation & Sanitization

**REST API Validation**:
```php
// Custom endpoint with validation
register_rest_route('custom/v1', '/posts', array(
    'methods' => 'POST',
    'callback' => 'create_custom_post',
    'args' => array(
        'title' => array(
            'required' => true,
            'type' => 'string',
            'sanitize_callback' => 'sanitize_text_field',
            'validate_callback' => function($param) {
                return !empty($param) && strlen($param) <= 200;
            }
        ),
        'content' => array(
            'required' => true,
            'type' => 'string',
            'sanitize_callback' => 'wp_kses_post'
        )
    )
));
```

**GraphQL Validation**:
```php
// GraphQL input validation
add_filter('graphql_resolve_field', function($result, $source, $args, $context, $info) {
    // Custom validation logic
    if ($info->fieldName === 'createPost') {
        $title = $args['input']['title'] ?? '';
        if (strlen($title) > 200) {
            throw new GraphQL\Error\UserError('Title too long');
        }
    }
    return $result;
}, 10, 5);
```

## Permission System

### WordPress Capabilities

**Default Capabilities**:
- `read`: Read content
- `edit_posts`: Edit own posts
- `publish_posts`: Publish posts
- `delete_posts`: Delete posts
- `edit_others_posts`: Edit others' posts
- `manage_categories`: Manage taxonomies
- `manage_options`: Admin access

**Custom Capabilities**:
```php
// Add custom capabilities
add_action('init', function() {
    $role = get_role('editor');
    $role->add_cap('manage_api_keys');
    $role->add_cap('view_analytics');
});
```

### Role-Based Access Control

**GraphQL Permission Checks**:
```php
// GraphQL field permissions
add_filter('graphql_resolve_field', function($result, $source, $args, $context, $info) {
    if ($info->fieldName === 'posts' && !current_user_can('read')) {
        throw new GraphQL\Error\UserError('Insufficient permissions');
    }
    return $result;
}, 10, 5);
```

**REST API Permission Callbacks**:
```php
// Custom endpoint permissions
register_rest_route('custom/v1', '/admin-data', array(
    'methods' => 'GET',
    'callback' => 'get_admin_data',
    'permission_callback' => function() {
        return current_user_can('manage_options');
    }
));
```

## Security Headers

### Content Security Policy

```php
// CSP Headers
add_action('send_headers', function() {
    header("Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self' https://api.example.com;");
    header("X-Content-Type-Options: nosniff");
    header("X-Frame-Options: SAMEORIGIN");
    header("X-XSS-Protection: 1; mode=block");
    header("Referrer-Policy: strict-origin-when-cross-origin");
});
```

### Security Headers Implementation

```nginx
# nginx security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

## API Key Management

### Creating API Keys

```php
// API Key generation
function generate_api_key($user_id, $name) {
    $key = wp_generate_password(32, false);
    $hash = password_hash($key, PASSWORD_BCRYPT);
    
    update_user_meta($user_id, 'api_key_' . sanitize_key($name), array(
        'hash' => $hash,
        'created' => time(),
        'last_used' => null,
        'permissions' => array('read', 'write')
    ));
    
    return $key;
}
```

### API Key Authentication

```php
// API Key middleware
add_filter('rest_authentication_errors', function($result) {
    if (!empty($result)) {
        return $result;
    }
    
    $api_key = $_SERVER['HTTP_X_API_KEY'] ?? '';
    if (empty($api_key)) {
        return null;
    }
    
    $user = authenticate_api_key($api_key);
    if ($user) {
        wp_set_current_user($user->ID);
        return true;
    }
    
    return new WP_Error('invalid_api_key', 'Invalid API key', array('status' => 401));
});
```

## Logging & Monitoring

### Authentication Logging

```php
// Log authentication attempts
add_action('wp_login', function($user_login, $user) {
    error_log(sprintf(
        'Successful login: %s (ID: %d) from %s',
        $user_login,
        $user->ID,
        $_SERVER['REMOTE_ADDR']
    ));
}, 10, 2);

add_action('wp_login_failed', function($username) {
    error_log(sprintf(
        'Failed login attempt: %s from %s',
        $username,
        $_SERVER['REMOTE_ADDR']
    ));
});
```

### API Request Logging

```php
// Log API requests
add_filter('rest_pre_dispatch', function($result, $server, $request) {
    $endpoint = $request->get_route();
    $method = $request->get_method();
    $user = wp_get_current_user();
    
    error_log(sprintf(
        'API Request: %s %s by %s from %s',
        $method,
        $endpoint,
        $user->user_login ?: 'anonymous',
        $_SERVER['REMOTE_ADDR']
    ));
    
    return $result;
}, 10, 3);
```

## Security Best Practices

### 1. Environment-Specific Configuration

**Development**:
```php
// dev-config.php
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('SCRIPT_DEBUG', true);
define('JWT_AUTH_CORS_ENABLE', true);
```

**Production**:
```php
// prod-config.php
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('SCRIPT_DEBUG', false);
define('DISALLOW_FILE_EDIT', true);
define('AUTOMATIC_UPDATER_DISABLED', true);
```

### 2. Secret Management

**Azure Key Vault Integration**:
```php
// secrets.php
function get_secret($name) {
    $vault_url = 'https://your-vault.vault.azure.net/';
    $token = get_azure_token();
    
    $response = wp_remote_get($vault_url . "secrets/$name", array(
        'headers' => array(
            'Authorization' => "Bearer $token"
        )
    ));
    
    return json_decode(wp_remote_retrieve_body($response))->value;
}
```

### 3. Database Security

**Connection Security**:
```php
// wp-config.php
define('DB_HOST', 'localhost:3306');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

// Use SSL for database connections
define('MYSQL_SSL_CA', '/path/to/ca-cert.pem');
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
```

### 4. File Upload Security

**File Type Restrictions**:
```php
// Restrict file uploads
add_filter('upload_mimes', function($mimes) {
    // Remove potentially dangerous file types
    unset($mimes['exe']);
    unset($mimes['php']);
    unset($mimes['js']);
    
    // Allow only specific types
    return array(
        'jpg|jpeg|jpe' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'pdf' => 'application/pdf',
        'doc|docx' => 'application/msword'
    );
});
```

## Testing Security

### Penetration Testing

```bash
# SQL Injection testing
sqlmap -u "https://your-domain.com/wp-json/wp/v2/posts" --random-agent

# XSS testing
curl -X POST "https://your-domain.com/wp-json/wp/v2/comments" \
  -H "Content-Type: application/json" \
  -d '{"content":"<script>alert(1)</script>"}'

# Authentication bypass testing
curl "https://your-domain.com/wp-json/wp/v2/users/me" \
  -H "Authorization: Bearer invalid_token"
```

### Security Headers Testing

```bash
# Check security headers
curl -I https://your-domain.com/wp-json/wp/v2/posts

# Expected headers:
# X-Frame-Options: SAMEORIGIN
# X-Content-Type-Options: nosniff
# X-XSS-Protection: 1; mode=block
```

## Security Incident Response

### 1. Detection

**Monitoring Alerts**:
- Failed authentication attempts
- Unusual API usage patterns
- Error rate spikes
- Privilege escalation attempts

### 2. Response Procedures

**Immediate Actions**:
1. Block suspicious IP addresses
2. Revoke compromised tokens/keys
3. Review audit logs
4. Assess impact scope

**Recovery Steps**:
1. Patch vulnerabilities
2. Reset affected credentials
3. Update security configurations
4. Notify stakeholders

## Compliance & Auditing

### GDPR Compliance

```php
// Data export for GDPR
add_filter('wp_privacy_personal_data_exporters', function($exporters) {
    $exporters['api-tokens'] = array(
        'exporter_friendly_name' => 'API Tokens',
        'callback' => 'export_user_api_tokens'
    );
    return $exporters;
});

function export_user_api_tokens($email, $page = 1) {
    $user = get_user_by('email', $email);
    if (!$user) {
        return array('data' => array(), 'done' => true);
    }
    
    $tokens = get_user_meta($user->ID, 'api_tokens', true);
    // Export token metadata (not the actual tokens)
    
    return array(
        'data' => $export_data,
        'done' => true
    );
}
```

### Security Audit Logs

```php
// Comprehensive audit logging
function log_security_event($event_type, $details) {
    $log_entry = array(
        'timestamp' => current_time('mysql'),
        'event_type' => $event_type,
        'user_id' => get_current_user_id(),
        'ip_address' => $_SERVER['REMOTE_ADDR'],
        'user_agent' => $_SERVER['HTTP_USER_AGENT'],
        'details' => $details
    );
    
    // Store in database or external logging service
    wp_insert_post(array(
        'post_type' => 'security_log',
        'post_content' => json_encode($log_entry),
        'post_status' => 'private'
    ));
}
```

## Related Documentation

- **[JWT Documentation](./jwt.md)** - Detailed JWT implementation
- **[OAuth Guide](./oauth.md)** - OAuth 2.0 setup and usage
- **[Security Procedures](./security.md)** - Additional security measures
- **[API Reference](../README.md)** - Main API documentation

---

**Last Updated**: August 2025  
**Security Version**: 1.0.0
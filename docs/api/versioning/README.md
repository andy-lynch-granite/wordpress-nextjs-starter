# API Versioning Strategy

## Overview

This document outlines our comprehensive API versioning strategy for the headless WordPress + Next.js platform. Our approach ensures backward compatibility, smooth migrations, and clear communication of changes to API consumers.

## Versioning Philosophy

### Semantic Versioning

We follow [Semantic Versioning (SemVer)](https://semver.org/) for our API versions:

- **Major (X.0.0)**: Breaking changes that require code modifications
- **Minor (0.X.0)**: New features that are backward compatible
- **Patch (0.0.X)**: Bug fixes and security updates

### API Stability Promise

- **Current Version**: Supported with all features and bug fixes
- **Previous Major**: Supported with security fixes for 12 months
- **Deprecated Versions**: 6-month notice before removal

## Current API Versions

### GraphQL API
- **Current**: `v1.2.0` (August 2025)
- **Supported**: `v1.1.x`, `v1.0.x`
- **Deprecated**: None

### REST API
- **Current**: `v2.1.0` (August 2025)
- **Supported**: `v2.0.x`, `v1.3.x`
- **Deprecated**: `v1.2.x` (removal January 2026)

## Version Implementation

### GraphQL Versioning

GraphQL uses schema evolution rather than versioning:

#### Schema Versioning
```graphql
# Version information in schema
type Query {
  _version: String! # "1.2.0"
  _schemaVersion: String! # "2025-08-12"
  _deprecations: [Deprecation!]!
}

type Deprecation {
  field: String!
  reason: String!
  removalDate: String!
  replacement: String
}
```

#### Field Deprecation
```graphql
type Post {
  id: ID!
  title: String!
  
  # Deprecated field
  legacySlug: String @deprecated(reason: "Use 'slug' instead", removalDate: "2026-01-01")
  
  # New field
  slug: String!
}
```

#### Query Introspection
```graphql
query GetVersionInfo {
  _version
  _schemaVersion
  _deprecations {
    field
    reason
    removalDate
    replacement
  }
}
```

### REST API Versioning

REST API uses URL-based versioning:

#### Version in URL
```
# Current version
https://api.example.com/wp-json/wp/v2/posts

# Previous version (still supported)
https://api.example.com/wp-json/wp/v1/posts

# Custom endpoints
https://api.example.com/wp-json/custom/v1/posts
```

#### Version Headers
```http
# Request specific version
GET /wp-json/wp/v2/posts
Accept: application/json; version=2.1.0

# Response includes version
HTTP/1.1 200 OK
API-Version: 2.1.0
Supported-Versions: 2.1.0, 2.0.0, 1.3.0
Deprecated-Versions: 1.2.0
```

## Version Discovery

### GraphQL Schema Introspection

```javascript
// Check current schema version
const introspectionQuery = `
  query {
    __schema {
      queryType {
        name
      }
    }
    _version
    _deprecations {
      field
      reason
      removalDate
    }
  }
`;

const result = await graphql(schema, introspectionQuery);
console.log('API Version:', result.data._version);
```

### REST API Discovery

```javascript
// Check API version
const response = await fetch('/wp-json/wp/v2/');
const versionInfo = {
  current: response.headers.get('API-Version'),
  supported: response.headers.get('Supported-Versions')?.split(', '),
  deprecated: response.headers.get('Deprecated-Versions')?.split(', ')
};
```

### Version Endpoint

```http
GET /wp-json/api/version

{
  "current_version": "2.1.0",
  "supported_versions": ["2.1.0", "2.0.0", "1.3.0"],
  "deprecated_versions": ["1.2.0"],
  "latest_features": [
    {
      "version": "2.1.0",
      "feature": "Advanced search capabilities",
      "endpoint": "/wp-json/wp/v2/search"
    }
  ],
  "deprecation_notices": [
    {
      "version": "1.2.0",
      "removal_date": "2026-01-01",
      "migration_guide": "/docs/api/versioning/migration-guides/v1.2-to-v2.0.md"
    }
  ]
}
```

## Breaking Changes Policy

### What Constitutes a Breaking Change

**GraphQL**:
- Removing fields or types
- Changing field types
- Making nullable fields non-nullable
- Removing enum values
- Changing query/mutation behavior

**REST API**:
- Removing endpoints
- Changing HTTP methods
- Modifying response structure
- Changing required parameters
- Altering authentication requirements

### Non-Breaking Changes

**GraphQL**:
- Adding new fields
- Adding new types
- Adding enum values
- Making non-nullable fields nullable
- Adding optional arguments

**REST API**:
- Adding new endpoints
- Adding optional parameters
- Adding fields to responses
- Adding new HTTP methods to existing endpoints

## Deprecation Process

### 1. Deprecation Notice

**GraphQL Schema**:
```graphql
type Post {
  # Deprecated field with metadata
  oldField: String @deprecated(
    reason: "Use newField instead for better performance"
    removalDate: "2026-01-01"
  )
  
  # New field
  newField: String
}
```

**REST API Response**:
```http
GET /wp-json/wp/v1/posts

HTTP/1.1 200 OK
Warning: 299 - "API version 1.x is deprecated. Please migrate to v2.x"
Sunset: Wed, 01 Jan 2026 00:00:00 GMT
Link: </docs/api/versioning/migration-guides/v1-to-v2>; rel="migration-guide"
```

### 2. Communication Timeline

**T-6 months**: Deprecation announcement
- Blog post and documentation updates
- Email notifications to registered developers
- In-API warnings and headers

**T-3 months**: Stronger warnings
- Console warnings in development
- Dashboard notifications
- Migration tool availability

**T-1 month**: Final notice
- Breaking change warnings
- Last chance migration reminders

**T-0**: Version removal
- Endpoint returns 410 Gone
- Clear error messages with migration links

### 3. Deprecation Headers

```http
# Deprecated endpoint response
HTTP/1.1 200 OK
Warning: 299 - "This API version is deprecated"
Sunset: Wed, 01 Jan 2026 00:00:00 GMT
Deprecation: Wed, 01 Aug 2025 00:00:00 GMT
Link: </docs/api/versioning/migration-guides/v1-to-v2>; rel="migration-guide"
Link: </wp-json/wp/v2/posts>; rel="successor-version"
```

## Migration Guides

### Version Migration Process

1. **Assessment**: Review breaking changes
2. **Planning**: Create migration timeline
3. **Testing**: Test in development environment
4. **Gradual Migration**: Migrate endpoints incrementally
5. **Validation**: Ensure functionality in production
6. **Cleanup**: Remove old version usage

### Migration Tools

#### GraphQL Migration Helper

```javascript
// Migration validation utility
class GraphQLMigrationHelper {
  async validateQuery(query, targetVersion) {
    const analysis = await this.analyzeQuery(query);
    
    return {
      isCompatible: analysis.deprecatedFields.length === 0,
      deprecatedFields: analysis.deprecatedFields,
      suggestions: analysis.suggestions,
      migrationSteps: this.generateMigrationSteps(analysis)
    };
  }
  
  generateMigrationSteps(analysis) {
    return analysis.deprecatedFields.map(field => ({
      action: 'replace',
      old: field.name,
      new: field.replacement,
      type: 'field_rename'
    }));
  }
}
```

#### REST API Migration Checker

```javascript
// REST migration validation
class RESTMigrationChecker {
  async checkEndpoint(url, targetVersion) {
    const response = await fetch(url, {
      headers: { 'Accept': `application/json; version=${targetVersion}` }
    });
    
    const warnings = response.headers.get('Warning');
    const deprecations = this.parseDeprecations(warnings);
    
    return {
      status: response.status,
      hasDeprecations: deprecations.length > 0,
      deprecations,
      migrationRequired: response.headers.has('Sunset')
    };
  }
}
```

## Version Compatibility Matrix

### Feature Compatibility

| Feature | v1.0 | v1.1 | v1.2 | v2.0 | v2.1 |
|---------|------|------|------|------|------|
| Basic CRUD | ✅ | ✅ | ✅ | ✅ | ✅ |
| Custom Fields | ❌ | ✅ | ✅ | ✅ | ✅ |
| File Uploads | ❌ | ❌ | ✅ | ✅ | ✅ |
| Batch Operations | ❌ | ❌ | ❌ | ✅ | ✅ |
| Advanced Search | ❌ | ❌ | ❌ | ❌ | ✅ |

### Client Compatibility

| Client Version | API v1.x | API v2.0 | API v2.1 |
|----------------|----------|----------|----------|
| Legacy Client 1.x | ✅ | ⚠️ | ❌ |
| Standard Client 2.x | ⚠️ | ✅ | ✅ |
| Modern Client 3.x | ❌ | ✅ | ✅ |

Legend:
- ✅ Full support
- ⚠️ Partial support with warnings
- ❌ Not supported

## Testing Strategy

### Version Compatibility Tests

```javascript
// GraphQL version compatibility tests
describe('GraphQL Version Compatibility', () => {
  test('v1.0 queries work with v1.1 schema', async () => {
    const v1Query = `
      query {
        posts {
          nodes {
            id
            title
          }
        }
      }
    `;
    
    const result = await graphql(v1_1_schema, v1Query);
    expect(result.errors).toBeUndefined();
  });
  
  test('deprecated fields show warnings', async () => {
    const deprecatedQuery = `
      query {
        posts {
          nodes {
            legacyField  # deprecated
          }
        }
      }
    `;
    
    const result = await graphql(schema, deprecatedQuery);
    expect(result.extensions.warnings).toContain('legacyField is deprecated');
  });
});
```

### REST API Version Tests

```javascript
// REST API version tests
describe('REST API Versioning', () => {
  test('v1 endpoint returns deprecation headers', async () => {
    const response = await request(app)
      .get('/wp-json/wp/v1/posts')
      .expect(200);
    
    expect(response.headers.warning).toContain('deprecated');
    expect(response.headers.sunset).toBeDefined();
  });
  
  test('v2 endpoint has new features', async () => {
    const response = await request(app)
      .get('/wp-json/wp/v2/posts')
      .expect(200);
    
    expect(response.body[0]).toHaveProperty('meta');
    expect(response.body[0]).toHaveProperty('featured_media');
  });
});
```

## Version Documentation

### Change Documentation Format

```yaml
# version-2.1.0.yaml
version: "2.1.0"
release_date: "2025-08-12"
type: "minor"

features:
  - title: "Advanced Search"
    description: "New search endpoint with filters and facets"
    endpoint: "/wp-json/wp/v2/search"
    example: |
      GET /wp-json/wp/v2/search?q=technology&type=post&category=tech

fixes:
  - title: "Fixed pagination issue"
    description: "Resolved offset calculation in large datasets"
    issue: "#123"

deprecations:
  - field: "legacy_search"
    replacement: "search"
    removal_date: "2026-08-12"
    migration_guide: "/docs/migration/legacy-search.md"

breaking_changes: []
```

### Auto-Generated Documentation

```javascript
// Generate version documentation
class VersionDocGenerator {
  async generateDocs(fromVersion, toVersion) {
    const changes = await this.getChangesBetweenVersions(fromVersion, toVersion);
    
    return {
      summary: this.generateSummary(changes),
      breaking_changes: changes.breaking,
      new_features: changes.features,
      deprecations: changes.deprecations,
      migration_steps: this.generateMigrationSteps(changes)
    };
  }
}
```

## Monitoring & Analytics

### Version Usage Metrics

```javascript
// Track API version usage
add_filter('rest_pre_dispatch', function($result, $server, $request) {
    $version = $request->get_header('Accept');
    $endpoint = $request->get_route();
    
    // Log version usage
    log_api_usage([
        'version' => extract_version($version),
        'endpoint' => $endpoint,
        'timestamp' => time(),
        'user_agent' => $request->get_header('User-Agent')
    ]);
    
    return $result;
}, 10, 3);
```

### Deprecation Metrics

```sql
-- Version usage analytics
SELECT 
    api_version,
    COUNT(*) as request_count,
    COUNT(DISTINCT user_agent) as unique_clients,
    DATE(created_at) as date
FROM api_usage_logs 
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY api_version, DATE(created_at)
ORDER BY date DESC, request_count DESC;
```

## Related Documentation

- **[Changelog](./changelog.md)** - Detailed version history
- **[Migration Guides](./migration-guides/)** - Version-specific migration instructions
- **[API Reference](../README.md)** - Current API documentation
- **[Breaking Changes](./breaking-changes.md)** - All breaking changes log

---

**Last Updated**: August 2025  
**Document Version**: 1.0.0
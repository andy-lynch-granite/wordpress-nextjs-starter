# API Documentation

## Overview

This directory contains comprehensive API documentation for our headless WordPress + Next.js enterprise solution. Our API architecture provides both GraphQL and REST endpoints to support flexible content delivery and integration patterns.

## Quick Navigation

- 📊 **[GraphQL API](./graphql/README.md)** - Modern, flexible query language for content
- 🔌 **[REST API](./rest/README.md)** - Traditional REST endpoints for backward compatibility
- 🔐 **[Authentication](./authentication/README.md)** - Security and authentication procedures
- 📋 **[Versioning](./versioning/README.md)** - API versioning and changelog
- 💻 **[Code Examples](./examples/)** - Integration examples in multiple languages
- 🚀 **[Integration Guides](./integration/)** - Framework-specific integration guides
- 🤖 **[Automation](./automation/README.md)** - Automated documentation and testing

## API Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Applications                      │
│                 (Next.js, Mobile, etc.)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                API Gateway / CDN                           │
│                (Azure API Management)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼─────┐  ┌────▼─────┐  ┌───▼───────┐
│  GraphQL    │  │   REST   │  │   Auth    │
│   API       │  │   API    │  │ Service   │
│ (WPGraphQL) │  │ (WP-API) │  │   (JWT)   │
└─────────────┘  └──────────┘  └───────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
        ┌─────────────▼─────────────┐
        │      WordPress Core      │
        │        Database          │
        │        (MySQL)           │
        └───────────────────────────┘
```

## API Endpoints

### GraphQL Endpoint
- **URL**: `https://your-domain.com/graphql`
- **Purpose**: Primary API for content queries and mutations
- **Features**: Type-safe queries, introspection, real-time subscriptions

### REST Endpoints
- **Base URL**: `https://your-domain.com/wp-json/`
- **WordPress Core**: `/wp/v2/`
- **Custom Endpoints**: `/custom/v1/`
- **Purpose**: Legacy support and specific integrations

## Getting Started

### 1. Authentication
Before using the API, set up authentication:

```javascript
// JWT Authentication
const token = await fetch('/wp-json/jwt-auth/v1/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    username: 'your-username',
    password: 'your-password'
  })
});
```

### 2. GraphQL Query Example
```javascript
// Fetch latest posts
const query = `
  query GetPosts {
    posts(first: 10) {
      nodes {
        id
        title
        content
        featuredImage {
          node {
            sourceUrl
          }
        }
      }
    }
  }
`;

const response = await fetch('/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({ query })
});
```

### 3. REST API Example
```javascript
// Fetch posts via REST
const posts = await fetch('/wp-json/wp/v2/posts', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

## API Features

### Content Management
- **Posts & Pages**: Full CRUD operations
- **Custom Post Types**: Extended content types
- **Media Management**: File uploads and management
- **Taxonomies**: Categories, tags, and custom taxonomies
- **Users**: User management and profiles

### Advanced Features
- **Real-time Updates**: GraphQL subscriptions
- **Batch Operations**: Multiple operations in single request
- **Field Selection**: Request only needed data
- **Caching**: Intelligent caching strategies
- **Rate Limiting**: Built-in API rate limiting

### Security Features
- **JWT Authentication**: Secure token-based auth
- **Role-based Access**: WordPress capability system
- **CORS Configuration**: Cross-origin request handling
- **Input Validation**: Comprehensive input sanitization
- **Rate Limiting**: DDoS protection and fair usage

## Performance Considerations

### Caching
- **Query Caching**: GraphQL query result caching
- **CDN Integration**: Azure CDN for global distribution
- **Browser Caching**: Appropriate cache headers
- **Redis Caching**: Server-side object caching

### Optimization
- **Query Complexity Analysis**: Prevent expensive queries
- **Connection Pagination**: Efficient large dataset handling
- **Field Selection**: Minimize data transfer
- **Batch Loading**: Reduce N+1 query problems

## Error Handling

### GraphQL Errors
```json
{
  "errors": [
    {
      "message": "Post not found",
      "locations": [{"line": 2, "column": 3}],
      "path": ["post"],
      "extensions": {
        "code": "POST_NOT_FOUND",
        "category": "user"
      }
    }
  ]
}
```

### REST API Errors
```json
{
  "code": "rest_post_invalid_id",
  "message": "Invalid post ID.",
  "data": {
    "status": 404
  }
}
```

## Testing

### GraphQL Testing
- **GraphQL Playground**: Interactive query testing
- **Automated Testing**: Jest-based test suites
- **Schema Validation**: Continuous schema testing

### REST API Testing
- **Postman Collections**: Pre-built API test collections
- **PHPUnit Tests**: Server-side unit tests
- **Integration Tests**: End-to-end API testing

## Monitoring & Analytics

### API Metrics
- **Request Volume**: Real-time request monitoring
- **Response Times**: Performance tracking
- **Error Rates**: Error monitoring and alerting
- **Usage Patterns**: API usage analytics

### Debugging
- **Query Logging**: Detailed query logging
- **Error Tracking**: Comprehensive error reporting
- **Performance Profiling**: Query performance analysis

## Support & Resources

- **Developer Portal**: [Link to developer documentation]
- **API Status**: [Link to status page]
- **Support**: [Link to support channels]
- **Community**: [Link to developer community]

## Changelog

See [CHANGELOG.md](./versioning/changelog.md) for detailed API changes and version history.

---

**Last Updated**: August 2025  
**API Version**: v1.0.0  
**Documentation Version**: 1.0
# WordPress REST API Documentation

## Overview

The WordPress REST API provides a RESTful interface for interacting with our headless WordPress installation. While GraphQL is our primary API, the REST API offers backward compatibility and supports specific use cases where REST patterns are preferred.

## Base URL

```
https://your-domain.com/wp-json/
```

## API Namespaces

- **WordPress Core**: `/wp/v2/` - Standard WordPress endpoints
- **Custom Endpoints**: `/custom/v1/` - Our custom business logic
- **Authentication**: `/jwt-auth/v1/` - JWT authentication endpoints

## Authentication

### JWT Authentication

#### Get Token
```http
POST /wp-json/jwt-auth/v1/token
Content-Type: application/json

{
  "username": "your-username",
  "password": "your-password"
}
```

Response:
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "user_email": "user@example.com",
  "user_nicename": "username",
  "user_display_name": "Display Name"
}
```

#### Validate Token
```http
POST /wp-json/jwt-auth/v1/token/validate
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

#### Using Token in Requests
```http
GET /wp-json/wp/v2/posts
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

### Application Passwords

WordPress also supports Application Passwords for basic authentication:

```http
GET /wp-json/wp/v2/posts
Authorization: Basic base64(username:application_password)
```

## Core Endpoints

### Posts

#### Get All Posts
```http
GET /wp-json/wp/v2/posts
```

Query Parameters:
- `per_page` (int): Number of posts per page (default: 10, max: 100)
- `page` (int): Page number
- `search` (string): Search term
- `author` (int): Author ID
- `categories` (array): Category IDs
- `tags` (array): Tag IDs
- `status` (string): Post status (publish, draft, private, etc.)
- `orderby` (string): Sort field (date, title, menu_order, etc.)
- `order` (string): Sort direction (asc, desc)

Example:
```http
GET /wp-json/wp/v2/posts?per_page=5&categories=10&orderby=date&order=desc
```

Response:
```json
[
  {
    "id": 123,
    "date": "2025-08-12T10:00:00",
    "date_gmt": "2025-08-12T10:00:00",
    "guid": {
      "rendered": "https://example.com/?p=123"
    },
    "modified": "2025-08-12T10:00:00",
    "modified_gmt": "2025-08-12T10:00:00",
    "slug": "sample-post",
    "status": "publish",
    "type": "post",
    "link": "https://example.com/sample-post/",
    "title": {
      "rendered": "Sample Post Title"
    },
    "content": {
      "rendered": "<p>Post content here...</p>",
      "protected": false
    },
    "excerpt": {
      "rendered": "<p>Post excerpt...</p>",
      "protected": false
    },
    "author": 1,
    "featured_media": 456,
    "comment_status": "open",
    "ping_status": "open",
    "sticky": false,
    "template": "",
    "format": "standard",
    "meta": {},
    "categories": [10, 15],
    "tags": [20, 25],
    "_links": {
      "self": [{"href": "https://example.com/wp-json/wp/v2/posts/123"}],
      "collection": [{"href": "https://example.com/wp-json/wp/v2/posts"}],
      "about": [{"href": "https://example.com/wp-json/wp/v2/types/post"}],
      "author": [{"embeddable": true, "href": "https://example.com/wp-json/wp/v2/users/1"}],
      "replies": [{"embeddable": true, "href": "https://example.com/wp-json/wp/v2/comments?post=123"}],
      "wp:featuredmedia": [{"embeddable": true, "href": "https://example.com/wp-json/wp/v2/media/456"}],
      "wp:attachment": [{"href": "https://example.com/wp-json/wp/v2/media?parent=123"}],
      "wp:term": [
        {"taxonomy": "category", "embeddable": true, "href": "https://example.com/wp-json/wp/v2/categories?post=123"},
        {"taxonomy": "post_tag", "embeddable": true, "href": "https://example.com/wp-json/wp/v2/tags?post=123"}
      ]
    }
  }
]
```

#### Get Single Post
```http
GET /wp-json/wp/v2/posts/{id}
```

#### Create Post
```http
POST /wp-json/wp/v2/posts
Authorization: Bearer {token}
Content-Type: application/json

{
  "title": "New Post Title",
  "content": "Post content here",
  "status": "publish",
  "categories": [10],
  "tags": [20, 25],
  "featured_media": 456
}
```

#### Update Post
```http
PUT /wp-json/wp/v2/posts/{id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "title": "Updated Post Title",
  "content": "Updated content"
}
```

#### Delete Post
```http
DELETE /wp-json/wp/v2/posts/{id}
Authorization: Bearer {token}
```

### Pages

#### Get All Pages
```http
GET /wp-json/wp/v2/pages
```

Query Parameters:
- `per_page` (int): Number of pages per page
- `page` (int): Page number
- `search` (string): Search term
- `parent` (int): Parent page ID
- `menu_order` (int): Menu order
- `orderby` (string): Sort field
- `order` (string): Sort direction

#### Get Page by Slug
```http
GET /wp-json/wp/v2/pages?slug=about-us
```

### Media

#### Get All Media
```http
GET /wp-json/wp/v2/media
```

#### Upload Media
```http
POST /wp-json/wp/v2/media
Authorization: Bearer {token}
Content-Type: multipart/form-data
Content-Disposition: attachment; filename="image.jpg"

[binary file data]
```

Response:
```json
{
  "id": 789,
  "date": "2025-08-12T10:00:00",
  "slug": "image",
  "type": "attachment",
  "link": "https://example.com/image/",
  "title": {
    "rendered": "image"
  },
  "author": 1,
  "mime_type": "image/jpeg",
  "media_details": {
    "width": 1920,
    "height": 1080,
    "file": "2025/08/image.jpg",
    "sizes": {
      "thumbnail": {
        "file": "image-150x150.jpg",
        "width": 150,
        "height": 150,
        "source_url": "https://example.com/wp-content/uploads/2025/08/image-150x150.jpg"
      },
      "medium": {
        "file": "image-300x169.jpg",
        "width": 300,
        "height": 169,
        "source_url": "https://example.com/wp-content/uploads/2025/08/image-300x169.jpg"
      },
      "full": {
        "file": "image.jpg",
        "width": 1920,
        "height": 1080,
        "source_url": "https://example.com/wp-content/uploads/2025/08/image.jpg"
      }
    }
  },
  "source_url": "https://example.com/wp-content/uploads/2025/08/image.jpg"
}
```

### Categories

#### Get All Categories
```http
GET /wp-json/wp/v2/categories
```

#### Create Category
```http
POST /wp-json/wp/v2/categories
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "Technology",
  "description": "Posts about technology",
  "slug": "technology",
  "parent": 0
}
```

### Tags

#### Get All Tags
```http
GET /wp-json/wp/v2/tags
```

#### Create Tag
```http
POST /wp-json/wp/v2/tags
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "React",
  "description": "React.js related posts",
  "slug": "react"
}
```

### Users

#### Get All Users
```http
GET /wp-json/wp/v2/users
```

#### Get Current User
```http
GET /wp-json/wp/v2/users/me
Authorization: Bearer {token}
```

#### Update User Profile
```http
PUT /wp-json/wp/v2/users/me
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "New Display Name",
  "description": "Updated bio"
}
```

### Comments

#### Get Comments for Post
```http
GET /wp-json/wp/v2/comments?post=123
```

#### Create Comment
```http
POST /wp-json/wp/v2/comments
Content-Type: application/json

{
  "post": 123,
  "author_name": "John Doe",
  "author_email": "john@example.com",
  "content": "Great post!"
}
```

## Custom Endpoints

### Custom Content Types

#### Get Portfolio Items
```http
GET /wp-json/custom/v1/portfolio
```

#### Get Team Members
```http
GET /wp-json/custom/v1/team
```

### Custom Business Logic

#### Get Site Configuration
```http
GET /wp-json/custom/v1/site-config
```

Response:
```json
{
  "site_name": "My Website",
  "site_description": "A great website",
  "social_media": {
    "twitter": "@mywebsite",
    "facebook": "mywebsite",
    "instagram": "mywebsite"
  },
  "contact_info": {
    "email": "info@mywebsite.com",
    "phone": "+1 (555) 123-4567",
    "address": "123 Main St, City, State 12345"
  }
}
```

#### Search Across All Content
```http
GET /wp-json/custom/v1/search?q=technology&type=all
```

## Embedding Related Data

Use the `_embed` parameter to include related data:

```http
GET /wp-json/wp/v2/posts?_embed
```

This includes:
- Author information
- Featured media
- Categories and tags
- Comments

## Custom Fields (ACF)

### Get Post with ACF Fields
```http
GET /wp-json/wp/v2/posts/123?acf_format=standard
```

Response includes ACF fields:
```json
{
  "id": 123,
  "title": {
    "rendered": "Sample Post"
  },
  "acf": {
    "hero_title": "Welcome to Our Site",
    "hero_subtitle": "We build amazing things",
    "hero_image": {
      "ID": 456,
      "url": "https://example.com/image.jpg",
      "alt": "Hero image"
    },
    "content_blocks": [
      {
        "acf_fc_layout": "text_block",
        "text": "Some text content"
      },
      {
        "acf_fc_layout": "image_block",
        "image": {
          "ID": 789,
          "url": "https://example.com/block-image.jpg"
        },
        "caption": "Image caption"
      }
    ]
  }
}
```

## Error Handling

### HTTP Status Codes

- `200 OK`: Successful request
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request data
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error

### Error Response Format

```json
{
  "code": "rest_post_invalid_id",
  "message": "Invalid post ID.",
  "data": {
    "status": 404
  }
}
```

### Common Error Codes

- `rest_forbidden`: Insufficient permissions
- `rest_post_invalid_id`: Invalid post ID
- `rest_user_invalid_id`: Invalid user ID
- `rest_no_route`: Endpoint not found
- `rest_invalid_param`: Invalid parameter value

## Rate Limiting

### Default Limits
- **Authenticated requests**: 1000 requests per hour
- **Unauthenticated requests**: 100 requests per hour

### Headers
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## Caching

### Cache Headers
```http
Cache-Control: public, max-age=300
ETag: "abc123"
Last-Modified: Mon, 12 Aug 2025 10:00:00 GMT
```

### Cache Invalidation
Cache is automatically invalidated when content is modified.

## Pagination

### Link Headers
```http
Link: <https://example.com/wp-json/wp/v2/posts?page=2>; rel="next",
      <https://example.com/wp-json/wp/v2/posts?page=5>; rel="last"
```

### Pagination Headers
```http
X-WP-Total: 50
X-WP-TotalPages: 5
```

## CORS Support

CORS is enabled for all origins during development. In production, configure specific origins:

```http
Access-Control-Allow-Origin: https://your-frontend-domain.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type
```

## Code Examples

### JavaScript/Fetch

```javascript
// Get posts
const posts = await fetch('/wp-json/wp/v2/posts')
  .then(response => response.json());

// Create post with authentication
const newPost = await fetch('/wp-json/wp/v2/posts', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    title: 'New Post',
    content: 'Post content',
    status: 'publish'
  })
}).then(response => response.json());
```

### cURL

```bash
# Get posts
curl https://example.com/wp-json/wp/v2/posts

# Create post
curl -X POST https://example.com/wp-json/wp/v2/posts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "title": "New Post",
    "content": "Post content",
    "status": "publish"
  }'
```

### PHP

```php
// Get posts
$response = wp_remote_get('https://example.com/wp-json/wp/v2/posts');
$posts = json_decode(wp_remote_retrieve_body($response), true);

// Create post with authentication
$response = wp_remote_post('https://example.com/wp-json/wp/v2/posts', [
    'headers' => [
        'Content-Type' => 'application/json',
        'Authorization' => 'Bearer ' . $token
    ],
    'body' => json_encode([
        'title' => 'New Post',
        'content' => 'Post content',
        'status' => 'publish'
    ])
]);
```

## Testing

### Postman Collection
Import our Postman collection for testing all endpoints:
[Download Collection](../examples/postman/wordpress-rest-api.json)

### Unit Tests

```javascript
describe('WordPress REST API', () => {
  test('should fetch posts', async () => {
    const response = await request(app)
      .get('/wp-json/wp/v2/posts')
      .expect(200);

    expect(Array.isArray(response.body)).toBe(true);
  });

  test('should create post with authentication', async () => {
    const response = await request(app)
      .post('/wp-json/wp/v2/posts')
      .set('Authorization', `Bearer ${token}`)
      .send({
        title: 'Test Post',
        content: 'Test content',
        status: 'publish'
      })
      .expect(201);

    expect(response.body.title.rendered).toBe('Test Post');
  });
});
```

## Security Best Practices

### Input Validation
All input is validated and sanitized automatically by WordPress core.

### Permission Checks
Endpoints respect WordPress capabilities and user roles.

### Rate Limiting
Implement rate limiting to prevent abuse.

### HTTPS Only
Always use HTTPS in production environments.

## Related Documentation

- **[GraphQL API](../graphql/README.md)** - Modern GraphQL interface
- **[Authentication](../authentication/README.md)** - Authentication methods
- **[Code Examples](../examples/)** - Integration examples
- **[WordPress Core API](https://developer.wordpress.org/rest-api/)** - Official documentation

---

**Last Updated**: August 2025  
**API Version**: 2.0.0
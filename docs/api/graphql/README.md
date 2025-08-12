# GraphQL API Documentation

## Overview

Our GraphQL API provides a modern, efficient way to query and manipulate content in our headless WordPress setup. Built on WPGraphQL, it offers type-safe queries, real-time capabilities, and flexible data fetching patterns perfect for modern applications.

## Endpoint Information

- **URL**: `https://your-domain.com/graphql`
- **Method**: `POST`
- **Content-Type**: `application/json`
- **Authentication**: JWT Bearer tokens (optional for public content)

## Getting Started

### 1. Basic Query Structure

```graphql
query {
  posts(first: 5) {
    nodes {
      id
      title
      content
      date
      author {
        node {
          name
        }
      }
    }
  }
}
```

### 2. Using Variables

```graphql
query GetPost($id: ID!) {
  post(id: $id) {
    id
    title
    content
    featuredImage {
      node {
        sourceUrl
        altText
      }
    }
  }
}
```

Variables:
```json
{
  "id": "cG9zdDoxMjM="
}
```

### 3. Mutations

```graphql
mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) {
    post {
      id
      title
      status
    }
  }
}
```

## Core Schema Types

### Post Type

```graphql
type Post {
  id: ID!
  databaseId: Int!
  title: String
  content: String
  excerpt: String
  slug: String
  status: PostStatusEnum
  date: String
  modified: String
  author: NodeWithAuthorToUserConnectionEdge
  featuredImage: NodeWithFeaturedImageToMediaItemConnectionEdge
  categories: PostToCategoryConnection
  tags: PostToTagConnection
  customFields: [PostCustomField]
}
```

### Page Type

```graphql
type Page {
  id: ID!
  databaseId: Int!
  title: String
  content: String
  slug: String
  status: PostStatusEnum
  date: String
  modified: String
  author: NodeWithAuthorToUserConnectionEdge
  featuredImage: NodeWithFeaturedImageToMediaItemConnectionEdge
  parent: HierarchicalContentNodeToParentContentNodeConnectionEdge
  children: HierarchicalContentNodeToChildContentNodeConnection
}
```

### User Type

```graphql
type User {
  id: ID!
  databaseId: Int!
  username: String
  name: String
  firstName: String
  lastName: String
  email: String
  description: String
  avatar: Avatar
  posts: UserToPostConnection
  pages: UserToPageConnection
  roles: UserToUserRoleConnection
}
```

### MediaItem Type

```graphql
type MediaItem {
  id: ID!
  databaseId: Int!
  title: String
  caption: String
  altText: String
  description: String
  sourceUrl: String
  mimeType: String
  fileSize: Int
  width: Int
  height: Int
  sizes: String
}
```

## Common Queries

### Get All Posts

```graphql
query GetAllPosts($first: Int, $after: String) {
  posts(first: $first, after: $after) {
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
    edges {
      node {
        id
        title
        excerpt
        slug
        date
        author {
          node {
            name
            avatar {
              url
            }
          }
        }
        featuredImage {
          node {
            sourceUrl
            altText
          }
        }
        categories {
          nodes {
            name
            slug
          }
        }
      }
    }
  }
}
```

### Get Single Post by Slug

```graphql
query GetPostBySlug($slug: ID!) {
  post(id: $slug, idType: SLUG) {
    id
    title
    content
    excerpt
    date
    modified
    author {
      node {
        name
        description
        avatar {
          url
        }
      }
    }
    featuredImage {
      node {
        sourceUrl
        altText
        caption
      }
    }
    categories {
      nodes {
        name
        slug
      }
    }
    tags {
      nodes {
        name
        slug
      }
    }
    seo {
      title
      metaDesc
      opengraphImage {
        sourceUrl
      }
    }
  }
}
```

### Get Navigation Menu

```graphql
query GetMenu($location: MenuLocationEnum!) {
  menu(id: $location, idType: LOCATION) {
    id
    name
    menuItems {
      nodes {
        id
        label
        url
        target
        parentId
        childItems {
          nodes {
            id
            label
            url
            target
          }
        }
      }
    }
  }
}
```

### Search Content

```graphql
query SearchContent($searchTerm: String!) {
  contentNodes(where: {search: $searchTerm}) {
    nodes {
      ... on Post {
        id
        title
        excerpt
        slug
        date
      }
      ... on Page {
        id
        title
        excerpt
        slug
      }
    }
  }
}
```

## Mutations

### Create Post

```graphql
mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) {
    post {
      id
      databaseId
      title
      content
      status
      slug
    }
    clientMutationId
  }
}
```

Input:
```json
{
  "input": {
    "title": "My New Post",
    "content": "This is the post content",
    "status": "PUBLISH",
    "authorId": 1,
    "categories": {
      "append": ["dGVybTox"]
    }
  }
}
```

### Update Post

```graphql
mutation UpdatePost($input: UpdatePostInput!) {
  updatePost(input: $input) {
    post {
      id
      title
      content
      status
      modified
    }
  }
}
```

### Delete Post

```graphql
mutation DeletePost($input: DeletePostInput!) {
  deletePost(input: $input) {
    deletedId
    post {
      id
      title
    }
  }
}
```

## Custom Fields (ACF Integration)

### Querying ACF Fields

```graphql
query GetPostWithACF($id: ID!) {
  post(id: $id) {
    id
    title
    acfFields {
      heroTitle
      heroSubtitle
      heroImage {
        sourceUrl
        altText
      }
      contentBlocks {
        ... on AcfContentBlocksTextBlock {
          fieldGroupName
          text
        }
        ... on AcfContentBlocksImageBlock {
          fieldGroupName
          image {
            sourceUrl
            altText
          }
          caption
        }
      }
    }
  }
}
```

## Pagination

### Cursor-based Pagination

```graphql
query GetPostsPaginated($first: Int, $after: String) {
  posts(first: $first, after: $after) {
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
    edges {
      cursor
      node {
        id
        title
        slug
      }
    }
  }
}
```

### Offset-based Pagination

```graphql
query GetPostsOffset($first: Int, $offset: Int) {
  posts(first: $first, where: {offsetPagination: {offset: $offset}}) {
    nodes {
      id
      title
      slug
    }
  }
}
```

## Filtering and Sorting

### Filter Posts by Category

```graphql
query GetPostsByCategory($categoryName: String!) {
  posts(where: {categoryName: $categoryName}) {
    nodes {
      id
      title
      excerpt
      slug
    }
  }
}
```

### Sort Posts by Date

```graphql
query GetPostsSorted {
  posts(where: {orderby: {field: DATE, order: DESC}}) {
    nodes {
      id
      title
      date
    }
  }
}
```

### Filter by Date Range

```graphql
query GetPostsByDateRange($after: String!, $before: String!) {
  posts(where: {
    dateQuery: {
      after: $after,
      before: $before
    }
  }) {
    nodes {
      id
      title
      date
    }
  }
}
```

## Authentication

### Public Queries
Most content queries can be performed without authentication:

```javascript
const response = await fetch('/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    query: `
      query {
        posts {
          nodes {
            id
            title
          }
        }
      }
    `
  })
});
```

### Authenticated Queries
For private content or mutations, include JWT token:

```javascript
const response = await fetch('/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${jwtToken}`
  },
  body: JSON.stringify({
    query: `
      mutation {
        createPost(input: {title: "New Post"}) {
          post {
            id
            title
          }
        }
      }
    `
  })
});
```

## Error Handling

### GraphQL Error Response

```json
{
  "errors": [
    {
      "message": "You do not have permission to create posts.",
      "locations": [{"line": 2, "column": 3}],
      "path": ["createPost"],
      "extensions": {
        "code": "FORBIDDEN",
        "category": "user"
      }
    }
  ],
  "data": {
    "createPost": null
  }
}
```

### Common Error Codes

- `UNAUTHENTICATED`: No valid authentication provided
- `FORBIDDEN`: Insufficient permissions
- `NOT_FOUND`: Requested resource doesn't exist
- `INVALID_INPUT`: Invalid input data
- `INTERNAL_ERROR`: Server-side error

## Performance Optimization

### Query Complexity Analysis
Our API implements query complexity analysis to prevent expensive queries:

```graphql
# This query might be rejected if too complex
query ExpensiveQuery {
  posts {
    nodes {
      comments {
        nodes {
          replies {
            nodes {
              author {
                node {
                  posts {
                    nodes {
                      title
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

### Query Depth Limiting
Maximum query depth is limited to 15 levels to prevent deeply nested queries.

### Field Selection Best Practices

```graphql
# Good: Request only needed fields
query OptimizedQuery {
  posts {
    nodes {
      id
      title
      excerpt
    }
  }
}

# Avoid: Requesting unnecessary fields
query NonOptimizedQuery {
  posts {
    nodes {
      id
      title
      content  # Large field, only request if needed
      excerpt
      author {
        node {
          posts {  # Expensive nested query
            nodes {
              title
            }
          }
        }
      }
    }
  }
}
```

## Caching

### Query Caching
- **Client-side**: Apollo Client, Relay, or custom caching
- **Server-side**: Redis-based query result caching
- **CDN**: CloudFlare or Azure CDN for GET requests

### Cache Invalidation
Cache is automatically invalidated when content is modified:

```graphql
mutation UpdatePost($input: UpdatePostInput!) {
  updatePost(input: $input) {
    post {
      id
      title
      modified  # Triggers cache invalidation
    }
  }
}
```

## Real-time Features (Subscriptions)

### Post Updates Subscription

```graphql
subscription PostUpdated($postId: ID!) {
  postUpdated(postId: $postId) {
    id
    title
    content
    modified
  }
}
```

### Comments Subscription

```graphql
subscription NewComments($postId: ID!) {
  commentAdded(postId: $postId) {
    id
    content
    author {
      name
    }
    date
  }
}
```

## Schema Introspection

### Get Schema Types

```graphql
query IntrospectionQuery {
  __schema {
    types {
      name
      kind
      description
    }
  }
}
```

### Get Type Details

```graphql
query GetTypeInfo {
  __type(name: "Post") {
    name
    kind
    description
    fields {
      name
      type {
        name
        kind
      }
      description
    }
  }
}
```

## Testing

### GraphQL Playground
Access the interactive GraphQL Playground at:
`https://your-domain.com/graphql`

### Example Test Query

```javascript
// Jest test example
describe('GraphQL API', () => {
  test('should fetch posts', async () => {
    const query = `
      query {
        posts(first: 5) {
          nodes {
            id
            title
          }
        }
      }
    `;

    const response = await request(app)
      .post('/graphql')
      .send({ query })
      .expect(200);

    expect(response.body.data.posts.nodes).toHaveLength(5);
  });
});
```

## Related Documentation

- **[Schema Types](./schema/types.md)** - Detailed type definitions
- **[Available Queries](./schema/queries.md)** - Complete query reference
- **[Mutations](./schema/mutations.md)** - All available mutations
- **[Authentication](../authentication/README.md)** - Authentication setup
- **[Integration Examples](../examples/)** - Code examples

---

**Last Updated**: August 2025  
**Schema Version**: 1.0.0
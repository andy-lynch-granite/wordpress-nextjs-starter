# Next.js Integration Guide

## Overview

This guide demonstrates how to integrate our headless WordPress API with Next.js 14+ applications using the App Router. We'll cover both GraphQL and REST API integration patterns, data fetching strategies, and performance optimizations.

## Installation & Setup

### Dependencies

```bash
npm install @apollo/client graphql
# OR for REST API only
npm install swr axios
```

### Environment Configuration

Create `.env.local`:

```bash
# WordPress API Configuration
NEXT_PUBLIC_WORDPRESS_URL=https://your-wordpress-domain.com
NEXT_PUBLIC_GRAPHQL_ENDPOINT=https://your-wordpress-domain.com/graphql
NEXT_PUBLIC_REST_API_BASE=https://your-wordpress-domain.com/wp-json/wp/v2

# Authentication (for admin features)
WORDPRESS_AUTH_USERNAME=your-username
WORDPRESS_AUTH_PASSWORD=your-password

# Internal URLs (for SSR/SSG)
WORDPRESS_INTERNAL_URL=http://wordpress:80
GRAPHQL_INTERNAL_ENDPOINT=http://wordpress:80/graphql
```

## GraphQL Integration

### Apollo Client Setup

Create `lib/apollo-client.js`:

```javascript
import { ApolloClient, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT,
});

const authLink = setContext((_, { headers }) => {
  // Get auth token from wherever you store it (localStorage, cookies, etc.)
  const token = typeof window !== 'undefined' ? localStorage.getItem('authToken') : null;

  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    }
  };
});

const client = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache({
    typePolicies: {
      Post: {
        fields: {
          categories: {
            merge(existing = [], incoming) {
              return incoming;
            },
          },
          tags: {
            merge(existing = [], incoming) {
              return incoming;
            },
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      nextFetchPolicy: 'cache-and-network',
    },
  },
});

export default client;
```

### GraphQL Queries

Create `lib/queries.js`:

```javascript
import { gql } from '@apollo/client';

export const GET_POSTS = gql`
  query GetPosts($first: Int!, $after: String) {
    posts(first: $first, after: $after, where: { status: PUBLISH }) {
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
          databaseId
          title
          excerpt
          slug
          date
          modified
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
              mediaDetails {
                width
                height
                sizes {
                  name
                  sourceUrl
                  width
                  height
                }
              }
            }
          }
          categories {
            nodes {
              id
              name
              slug
            }
          }
          tags {
            nodes {
              id
              name
              slug
            }
          }
        }
      }
    }
  }
`;

export const GET_POST_BY_SLUG = gql`
  query GetPostBySlug($slug: ID!) {
    post(id: $slug, idType: SLUG) {
      id
      databaseId
      title
      content
      excerpt
      slug
      date
      modified
      seo {
        title
        metaDesc
        opengraphImage {
          sourceUrl
        }
      }
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
          mediaDetails {
            width
            height
            sizes {
              name
              sourceUrl
              width
              height
            }
          }
        }
      }
      categories {
        nodes {
          id
          name
          slug
          description
        }
      }
      tags {
        nodes {
          id
          name
          slug
          description
        }
      }
    }
  }
`;

export const GET_PAGES = gql`
  query GetPages {
    pages(where: { status: PUBLISH }) {
      nodes {
        id
        title
        slug
        content
        modified
      }
    }
  }
`;

export const SEARCH_CONTENT = gql`
  query SearchContent($searchTerm: String!) {
    contentNodes(where: { search: $searchTerm }) {
      nodes {
        ... on Post {
          id
          title
          excerpt
          slug
          date
          contentType {
            node {
              name
            }
          }
        }
        ... on Page {
          id
          title
          excerpt
          slug
          date
          contentType {
            node {
              name
            }
          }
        }
      }
    }
  }
`;
```

### Apollo Provider Setup

Update `app/layout.js`:

```javascript
'use client';

import { ApolloProvider } from '@apollo/client';
import client from '@/lib/apollo-client';

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <ApolloProvider client={client}>
          {children}
        </ApolloProvider>
      </body>
    </html>
  );
}
```

## Data Fetching Patterns

### Static Site Generation (SSG)

#### Blog Posts List Page

`app/blog/page.js`:

```javascript
import { ApolloClient, InMemoryCache } from '@apollo/client';
import { GET_POSTS } from '@/lib/queries';
import PostCard from '@/components/PostCard';

// Internal Apollo client for SSG/SSR
const serverClient = new ApolloClient({
  uri: process.env.GRAPHQL_INTERNAL_ENDPOINT || process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT,
  cache: new InMemoryCache(),
});

async function getPosts() {
  const { data } = await serverClient.query({
    query: GET_POSTS,
    variables: { first: 10 },
    context: {
      fetchOptions: {
        next: { revalidate: 3600 }, // Revalidate every hour
      },
    },
  });

  return data.posts.edges.map(edge => edge.node);
}

export default async function BlogPage() {
  const posts = await getPosts();

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-4xl font-bold mb-8">Blog</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {posts.map((post) => (
          <PostCard key={post.id} post={post} />
        ))}
      </div>
    </div>
  );
}

// Generate metadata for SEO
export async function generateMetadata() {
  return {
    title: 'Blog | Your Site',
    description: 'Latest blog posts and articles',
  };
}
```

#### Single Post Page with ISR

`app/blog/[slug]/page.js`:

```javascript
import { ApolloClient, InMemoryCache } from '@apollo/client';
import { GET_POST_BY_SLUG, GET_POSTS } from '@/lib/queries';
import { notFound } from 'next/navigation';
import Image from 'next/image';

const serverClient = new ApolloClient({
  uri: process.env.GRAPHQL_INTERNAL_ENDPOINT || process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT,
  cache: new InMemoryCache(),
});

async function getPost(slug) {
  try {
    const { data } = await serverClient.query({
      query: GET_POST_BY_SLUG,
      variables: { slug },
      context: {
        fetchOptions: {
          next: { revalidate: 3600 },
        },
      },
    });

    return data.post;
  } catch (error) {
    console.error('Error fetching post:', error);
    return null;
  }
}

export default async function PostPage({ params }) {
  const post = await getPost(params.slug);

  if (!post) {
    notFound();
  }

  return (
    <article className="container mx-auto px-4 py-8 max-w-4xl">
      {/* Featured Image */}
      {post.featuredImage && (
        <div className="mb-8">
          <Image
            src={post.featuredImage.node.sourceUrl}
            alt={post.featuredImage.node.altText || post.title}
            width={800}
            height={400}
            className="w-full h-auto rounded-lg"
            priority
          />
        </div>
      )}

      {/* Post Header */}
      <header className="mb-8">
        <h1 className="text-4xl font-bold mb-4">{post.title}</h1>
        
        <div className="flex items-center gap-4 text-gray-600 mb-4">
          {post.author?.node?.avatar && (
            <Image
              src={post.author.node.avatar.url}
              alt={post.author.node.name}
              width={40}
              height={40}
              className="rounded-full"
            />
          )}
          <div>
            <p className="font-medium">{post.author?.node?.name}</p>
            <p className="text-sm">
              {new Date(post.date).toLocaleDateString()}
            </p>
          </div>
        </div>

        {/* Categories and Tags */}
        <div className="flex flex-wrap gap-2">
          {post.categories?.nodes?.map((category) => (
            <span
              key={category.id}
              className="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm"
            >
              {category.name}
            </span>
          ))}
          {post.tags?.nodes?.map((tag) => (
            <span
              key={tag.id}
              className="bg-gray-100 text-gray-800 px-3 py-1 rounded-full text-sm"
            >
              #{tag.name}
            </span>
          ))}
        </div>
      </header>

      {/* Post Content */}
      <div 
        className="prose prose-lg max-w-none"
        dangerouslySetInnerHTML={{ __html: post.content }}
      />
    </article>
  );
}

// Generate static paths for posts
export async function generateStaticParams() {
  const { data } = await serverClient.query({
    query: GET_POSTS,
    variables: { first: 100 }, // Adjust based on your needs
  });

  return data.posts.edges.map((edge) => ({
    slug: edge.node.slug,
  }));
}

// Generate metadata for SEO
export async function generateMetadata({ params }) {
  const post = await getPost(params.slug);

  if (!post) {
    return {};
  }

  return {
    title: post.seo?.title || post.title,
    description: post.seo?.metaDesc || post.excerpt,
    openGraph: {
      title: post.seo?.title || post.title,
      description: post.seo?.metaDesc || post.excerpt,
      images: post.seo?.opengraphImage?.sourceUrl ? [
        {
          url: post.seo.opengraphImage.sourceUrl,
          width: 1200,
          height: 630,
          alt: post.title,
        },
      ] : [],
    },
  };
}
```

### Client-Side Data Fetching

#### Search Component

`components/SearchComponent.js`:

```javascript
'use client';

import { useState } from 'react';
import { useLazyQuery } from '@apollo/client';
import { SEARCH_CONTENT } from '@/lib/queries';

export default function SearchComponent() {
  const [searchTerm, setSearchTerm] = useState('');
  const [searchContent, { data, loading, error }] = useLazyQuery(SEARCH_CONTENT);

  const handleSearch = (e) => {
    e.preventDefault();
    if (searchTerm.trim()) {
      searchContent({ variables: { searchTerm } });
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <form onSubmit={handleSearch} className="mb-6">
        <div className="flex gap-2">
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search posts and pages..."
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            type="submit"
            disabled={loading}
            className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Searching...' : 'Search'}
          </button>
        </div>
      </form>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          Error: {error.message}
        </div>
      )}

      {data && (
        <div>
          <h2 className="text-2xl font-bold mb-4">
            Search Results ({data.contentNodes.nodes.length})
          </h2>
          
          {data.contentNodes.nodes.length === 0 ? (
            <p className="text-gray-600">No results found for "{searchTerm}"</p>
          ) : (
            <div className="space-y-4">
              {data.contentNodes.nodes.map((node) => (
                <div key={node.id} className="border border-gray-200 rounded-lg p-4">
                  <h3 className="text-xl font-semibold mb-2">
                    <a 
                      href={`/${node.contentType.node.name.toLowerCase()}/${node.slug}`}
                      className="text-blue-600 hover:text-blue-800"
                    >
                      {node.title}
                    </a>
                  </h3>
                  <p className="text-gray-600 mb-2">{node.excerpt}</p>
                  <div className="flex items-center gap-2 text-sm text-gray-500">
                    <span className="bg-gray-100 px-2 py-1 rounded">
                      {node.contentType.node.name}
                    </span>
                    <span>{new Date(node.date).toLocaleDateString()}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

## REST API Integration

### SWR Setup

Create `lib/api.js`:

```javascript
import useSWR from 'swr';

const REST_API_BASE = process.env.NEXT_PUBLIC_REST_API_BASE;

// Fetcher function for SWR
const fetcher = async (url) => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error('An error occurred while fetching the data.');
  }
  return response.json();
};

// Custom hooks for common API calls
export function usePosts(params = {}) {
  const queryString = new URLSearchParams({
    _embed: true,
    per_page: 10,
    ...params,
  }).toString();

  const { data, error, isLoading } = useSWR(
    `${REST_API_BASE}/posts?${queryString}`,
    fetcher
  );

  return {
    posts: data,
    isLoading,
    isError: error,
  };
}

export function usePost(slug) {
  const { data, error, isLoading } = useSWR(
    slug ? `${REST_API_BASE}/posts?slug=${slug}&_embed=true` : null,
    fetcher
  );

  return {
    post: data?.[0],
    isLoading,
    isError: error,
  };
}

export function useCategories() {
  const { data, error, isLoading } = useSWR(
    `${REST_API_BASE}/categories?per_page=100`,
    fetcher
  );

  return {
    categories: data,
    isLoading,
    isError: error,
  };
}

// Server-side fetch functions
export async function fetchPosts(params = {}) {
  const queryString = new URLSearchParams({
    _embed: true,
    per_page: 10,
    ...params,
  }).toString();

  const response = await fetch(`${REST_API_BASE}/posts?${queryString}`, {
    next: { revalidate: 3600 },
  });

  if (!response.ok) {
    throw new Error('Failed to fetch posts');
  }

  return response.json();
}

export async function fetchPostBySlug(slug) {
  const response = await fetch(`${REST_API_BASE}/posts?slug=${slug}&_embed=true`, {
    next: { revalidate: 3600 },
  });

  if (!response.ok) {
    throw new Error('Failed to fetch post');
  }

  const posts = await response.json();
  return posts[0] || null;
}
```

### REST API Component Example

`components/PostsList.js`:

```javascript
'use client';

import { usePosts } from '@/lib/api';
import Image from 'next/image';
import Link from 'next/link';

export default function PostsList({ initialPosts = [] }) {
  const { posts, isLoading, isError } = usePosts();

  // Use initial posts for SSR, then SWR data when available
  const displayPosts = posts || initialPosts;

  if (isError) {
    return <div className="text-red-600">Failed to load posts</div>;
  }

  if (isLoading && !displayPosts.length) {
    return <div className="text-gray-600">Loading posts...</div>;
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {displayPosts.map((post) => (
        <article key={post.id} className="bg-white rounded-lg shadow-md overflow-hidden">
          {post._embedded?.['wp:featuredmedia']?.[0] && (
            <Image
              src={post._embedded['wp:featuredmedia'][0].source_url}
              alt={post._embedded['wp:featuredmedia'][0].alt_text || post.title.rendered}
              width={400}
              height={250}
              className="w-full h-48 object-cover"
            />
          )}
          
          <div className="p-6">
            <h2 className="text-xl font-semibold mb-2">
              <Link 
                href={`/blog/${post.slug}`}
                className="text-gray-900 hover:text-blue-600"
              >
                {post.title.rendered}
              </Link>
            </h2>
            
            <div 
              className="text-gray-600 mb-4 line-clamp-3"
              dangerouslySetInnerHTML={{ __html: post.excerpt.rendered }}
            />
            
            <div className="flex items-center justify-between text-sm text-gray-500">
              <span>
                {post._embedded?.author?.[0]?.name}
              </span>
              <span>
                {new Date(post.date).toLocaleDateString()}
              </span>
            </div>
          </div>
        </article>
      ))}
    </div>
  );
}
```

## Performance Optimizations

### Image Optimization

Create `components/WordPressImage.js`:

```javascript
import Image from 'next/image';

const getOptimalImageSize = (mediaDetails, maxWidth = 800) => {
  if (!mediaDetails?.sizes) return null;

  const sizes = Object.values(mediaDetails.sizes).filter(size => 
    size.width <= maxWidth * 2 // Allow for 2x retina displays
  );

  return sizes.reduce((best, current) => 
    current.width > best.width ? current : best
  );
};

export default function WordPressImage({ 
  media, 
  alt, 
  className = '',
  priority = false,
  maxWidth = 800 
}) {
  if (!media) return null;

  const optimalSize = getOptimalImageSize(media.mediaDetails, maxWidth);
  const src = optimalSize?.sourceUrl || media.sourceUrl;
  const width = optimalSize?.width || media.mediaDetails?.width || 800;
  const height = optimalSize?.height || media.mediaDetails?.height || 600;

  return (
    <Image
      src={src}
      alt={alt || media.altText || ''}
      width={width}
      height={height}
      className={className}
      priority={priority}
      sizes={`(max-width: ${maxWidth}px) 100vw, ${maxWidth}px`}
    />
  );
}
```

### Incremental Static Regeneration (ISR)

Configure ISR in your page components:

```javascript
// In your page component
export const revalidate = 3600; // Revalidate every hour

// Or use dynamic revalidation
export async function generateStaticParams() {
  // Only pre-generate the most popular posts
  const { data } = await serverClient.query({
    query: GET_POSTS,
    variables: { first: 50 }, // Pre-generate top 50 posts
  });

  return data.posts.edges.map((edge) => ({
    slug: edge.node.slug,
  }));
}
```

### Caching Strategy

Create `lib/cache.js`:

```javascript
// Memory cache for server-side rendering
const cache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

export function getCached(key) {
  const item = cache.get(key);
  if (!item) return null;
  
  if (Date.now() > item.expiry) {
    cache.delete(key);
    return null;
  }
  
  return item.data;
}

export function setCache(key, data, ttl = CACHE_TTL) {
  cache.set(key, {
    data,
    expiry: Date.now() + ttl,
  });
}

// Use in your data fetching
export async function fetchWithCache(key, fetchFn, ttl) {
  const cached = getCached(key);
  if (cached) return cached;
  
  const data = await fetchFn();
  setCache(key, data, ttl);
  return data;
}
```

## Error Handling

### Error Boundary Component

`components/ErrorBoundary.js`:

```javascript
'use client';

import { Component } from 'react';

class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo);
    
    // Log error to monitoring service
    if (process.env.NODE_ENV === 'production') {
      // logErrorToService(error, errorInfo);
    }
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <div className="max-w-md w-full bg-white shadow-lg rounded-lg p-6">
            <div className="flex items-center mb-4">
              <div className="flex-shrink-0">
                <svg className="h-10 w-10 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3">
                <h3 className="text-lg font-medium text-gray-900">
                  Something went wrong
                </h3>
                <div className="mt-2 text-sm text-gray-500">
                  <p>We apologize for the inconvenience. Please try refreshing the page.</p>
                </div>
              </div>
            </div>
            <div className="mt-4">
              <button
                onClick={() => window.location.reload()}
                className="bg-red-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500"
              >
                Refresh Page
              </button>
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
```

## SEO Integration

### Metadata Generation

`lib/seo.js`:

```javascript
export function generatePostMetadata(post) {
  if (!post) return {};

  const title = post.seo?.title || post.title;
  const description = post.seo?.metaDesc || post.excerpt?.replace(/<[^>]*>/g, '').substring(0, 160);
  const images = [];

  if (post.seo?.opengraphImage?.sourceUrl) {
    images.push({
      url: post.seo.opengraphImage.sourceUrl,
      width: 1200,
      height: 630,
      alt: title,
    });
  } else if (post.featuredImage?.node?.sourceUrl) {
    images.push({
      url: post.featuredImage.node.sourceUrl,
      width: post.featuredImage.node.mediaDetails?.width || 1200,
      height: post.featuredImage.node.mediaDetails?.height || 630,
      alt: post.featuredImage.node.altText || title,
    });
  }

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      type: 'article',
      publishedTime: post.date,
      modifiedTime: post.modified,
      authors: [post.author?.node?.name].filter(Boolean),
      images,
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: images.map(img => img.url),
    },
    alternates: {
      canonical: `/blog/${post.slug}`,
    },
  };
}
```

## Deployment Considerations

### Environment Variables

```bash
# Production .env
NEXT_PUBLIC_WORDPRESS_URL=https://your-production-domain.com
NEXT_PUBLIC_GRAPHQL_ENDPOINT=https://your-production-domain.com/graphql

# Internal URLs for container communication
WORDPRESS_INTERNAL_URL=http://wordpress
GRAPHQL_INTERNAL_ENDPOINT=http://wordpress/graphql

# Optional: Enable ISR webhook revalidation
REVALIDATION_SECRET=your-secret-key
```

### Webhook Revalidation

Create `app/api/revalidate/route.js`:

```javascript
import { revalidatePath, revalidateTag } from 'next/cache';
import { NextResponse } from 'next/server';

export async function POST(request) {
  const secret = request.nextUrl.searchParams.get('secret');
  
  if (secret !== process.env.REVALIDATION_SECRET) {
    return NextResponse.json({ message: 'Invalid secret' }, { status: 401 });
  }

  try {
    const body = await request.json();
    const { action, post } = body;

    switch (action) {
      case 'post_updated':
      case 'post_published':
        // Revalidate specific post page
        revalidatePath(`/blog/${post.slug}`);
        // Revalidate blog list page
        revalidatePath('/blog');
        break;
      
      case 'post_deleted':
        // Revalidate blog list page
        revalidatePath('/blog');
        break;
      
      default:
        // Revalidate everything for unknown actions
        revalidatePath('/', 'layout');
    }

    return NextResponse.json({ revalidated: true, now: Date.now() });
  } catch (error) {
    console.error('Revalidation error:', error);
    return NextResponse.json(
      { message: 'Error revalidating' }, 
      { status: 500 }
    );
  }
}
```

## Testing

### Jest Configuration

`jest.config.js`:

```javascript
const nextJest = require('next/jest');

const createJestConfig = nextJest({
  dir: './',
});

const customJestConfig = {
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/$1',
  },
  testEnvironment: 'jest-environment-jsdom',
};

module.exports = createJestConfig(customJestConfig);
```

### Component Tests

`__tests__/PostCard.test.js`:

```javascript
import { render, screen } from '@testing-library/react';
import PostCard from '@/components/PostCard';

const mockPost = {
  id: '1',
  title: 'Test Post',
  excerpt: 'This is a test post excerpt',
  slug: 'test-post',
  date: '2025-08-12T10:00:00',
  author: {
    node: {
      name: 'John Doe',
    },
  },
  featuredImage: {
    node: {
      sourceUrl: 'https://example.com/image.jpg',
      altText: 'Test image',
    },
  },
  categories: {
    nodes: [
      { id: '1', name: 'Technology', slug: 'technology' },
    ],
  },
};

describe('PostCard', () => {
  it('renders post information correctly', () => {
    render(<PostCard post={mockPost} />);
    
    expect(screen.getByText('Test Post')).toBeInTheDocument();
    expect(screen.getByText(/This is a test post excerpt/)).toBeInTheDocument();
    expect(screen.getByText('John Doe')).toBeInTheDocument();
    expect(screen.getByText('Technology')).toBeInTheDocument();
  });

  it('creates correct link to post', () => {
    render(<PostCard post={mockPost} />);
    
    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('href', '/blog/test-post');
  });
});
```

## Best Practices

### 1. Data Fetching Strategy
- Use SSG for static content (blog posts, pages)
- Use ISR for content that updates occasionally
- Use client-side fetching for user-specific data
- Implement proper error boundaries and loading states

### 2. Performance
- Optimize images with Next.js Image component
- Implement proper caching strategies
- Use code splitting for large components
- Monitor Core Web Vitals

### 3. SEO
- Generate proper metadata for all pages
- Implement structured data where appropriate
- Use semantic HTML elements
- Ensure proper internal linking

### 4. Security
- Validate all user inputs
- Sanitize HTML content from WordPress
- Use environment variables for sensitive data
- Implement proper CORS policies

This integration guide provides a solid foundation for building performant, SEO-friendly Next.js applications with headless WordPress as the content management system.
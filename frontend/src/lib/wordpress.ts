import { ApolloClient, InMemoryCache, gql } from '@apollo/client'

// GraphQL client for build-time data fetching
const client = new ApolloClient({
  uri: process.env.WORDPRESS_GRAPHQL_URL || 'http://localhost:8081/index.php?graphql',
  cache: new InMemoryCache(),
  ssrMode: true, // Enable server-side rendering mode
})

// GraphQL queries
export const GET_ALL_POSTS = gql`
  query GetAllPosts {
    posts(first: 1000) {
      nodes {
        id
        slug
        title
        content
        excerpt
        date
        modified
        featuredImage {
          node {
            sourceUrl
            altText
            title
          }
        }
        author {
          node {
            name
            slug
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
      }
    }
  }
`

export const GET_POST_BY_SLUG = gql`
  query GetPostBySlug($slug: String!) {
    postBy(slug: $slug) {
      id
      slug
      title
      content
      excerpt
      date
      modified
      featuredImage {
        node {
          sourceUrl
          altText
          title
        }
      }
      author {
        node {
          name
          slug
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
    }
  }
`

export const GET_ALL_PAGES = gql`
  query GetAllPages {
    pages(first: 100) {
      nodes {
        id
        slug
        title
        content
        modified
      }
    }
  }
`

export const GET_SITE_SETTINGS = gql`
  query GetSiteSettings {
    generalSettings {
      title
      description
      url
    }
  }
`

// Mock data for when WordPress backend is not available
const mockPosts: Post[] = [
  {
    id: '1',
    slug: 'welcome-to-headless-wordpress',
    title: 'Welcome to Headless WordPress + Next.js',
    content: '<p>This is a demo post to showcase the headless WordPress setup. The WordPress backend will be deployed soon!</p><p>This static site is currently running on Azure Storage with automated CI/CD deployment via GitHub Actions.</p>',
    excerpt: '<p>A welcome post demonstrating the headless WordPress + Next.js setup deployed on Azure.</p>',
    date: new Date().toISOString(),
    modified: new Date().toISOString(),
    author: {
      node: {
        name: 'Demo Author',
        slug: 'demo-author'
      }
    },
    categories: {
      nodes: [
        { name: 'Getting Started', slug: 'getting-started' },
        { name: 'Azure', slug: 'azure' }
      ]
    },
    tags: {
      nodes: [
        { name: 'WordPress', slug: 'wordpress' },
        { name: 'Next.js', slug: 'nextjs' },
        { name: 'Azure', slug: 'azure' }
      ]
    }
  },
  {
    id: '2',
    slug: 'azure-deployment-guide',
    title: 'Azure Deployment Architecture',
    content: '<p>This headless WordPress + Next.js starter is designed for enterprise-grade deployment on Microsoft Azure.</p><h2>Current Status</h2><ul><li>✅ Azure Storage Static Website Hosting</li><li>✅ GitHub Actions CI/CD Pipeline</li><li>🚧 WordPress Backend (Container Apps) - Coming Soon</li><li>🚧 MySQL Database - Coming Soon</li></ul>',
    excerpt: '<p>Learn about the Azure deployment architecture for this headless WordPress setup.</p>',
    date: new Date(Date.now() - 86400000).toISOString(), // 1 day ago
    modified: new Date(Date.now() - 86400000).toISOString(),
    author: {
      node: {
        name: 'Azure Architect',
        slug: 'azure-architect'
      }
    },
    categories: {
      nodes: [
        { name: 'Architecture', slug: 'architecture' },
        { name: 'Azure', slug: 'azure' }
      ]
    },
    tags: {
      nodes: [
        { name: 'Azure', slug: 'azure' },
        { name: 'Deployment', slug: 'deployment' },
        { name: 'CI/CD', slug: 'cicd' }
      ]
    }
  }
]

const mockSiteSettings: SiteSettings = {
  title: 'WordPress + Next.js Starter',
  description: 'A modern headless WordPress starter deployed on Azure',
  url: 'https://wordpressnextjsdevstatic.z16.web.core.windows.net'
}

// Helper functions for static generation
export async function getAllPosts() {
  // Check if WordPress backend is available
  const wordpressUrl = process.env.WORDPRESS_GRAPHQL_URL || process.env.NEXT_PUBLIC_WORDPRESS_API_URL
  
  // Try WordPress REST API first, then GraphQL, then fall back to mock data
  if (!wordpressUrl || wordpressUrl.includes('localhost')) {
    console.log('WordPress backend not available, using mock data')
    return mockPosts
  }

  // Try WordPress REST API as fallback if GraphQL isn't available
  try {
    const restUrl = wordpressUrl.replace('/graphql', '/wp-json/wp/v2/posts')
    const response = await fetch(restUrl)
    if (response.ok) {
      const restPosts = await response.json()
      console.log('Using WordPress REST API data')
      return restPosts.map((post: any) => ({
        id: post.id.toString(),
        slug: post.slug,
        title: post.title.rendered,
        content: post.content.rendered,
        excerpt: post.excerpt.rendered,
        date: post.date,
        modified: post.modified,
        author: {
          node: {
            name: 'WordPress Author',
            slug: 'wp-author'
          }
        },
        categories: {
          nodes: []
        },
        tags: {
          nodes: []
        }
      }))
    }
  } catch (error) {
    console.log('WordPress REST API not available, trying GraphQL...')
  }

  try {
    const { data } = await client.query({
      query: GET_ALL_POSTS,
      errorPolicy: 'all'
    })
    return data?.posts?.nodes || mockPosts
  } catch (error) {
    console.error('Error fetching posts, falling back to mock data:', error)
    return mockPosts
  }
}

export async function getPostBySlug(slug: string) {
  // Check if WordPress backend is available
  const wordpressUrl = process.env.WORDPRESS_GRAPHQL_URL || process.env.NEXT_PUBLIC_WORDPRESS_API_URL
  
  if (!wordpressUrl || wordpressUrl.includes('localhost')) {
    console.log(`WordPress backend not available, using mock data for slug: ${slug}`)
    return mockPosts.find(post => post.slug === slug) || null
  }

  // Try WordPress REST API first
  try {
    const restUrl = wordpressUrl.replace('/graphql', `/wp-json/wp/v2/posts?slug=${slug}`)
    const response = await fetch(restUrl)
    if (response.ok) {
      const restPosts = await response.json()
      if (restPosts.length > 0) {
        const post = restPosts[0]
        console.log(`Using WordPress REST API data for slug: ${slug}`)
        return {
          id: post.id.toString(),
          slug: post.slug,
          title: post.title.rendered,
          content: post.content.rendered,
          excerpt: post.excerpt.rendered,
          date: post.date,
          modified: post.modified,
          author: {
            node: {
              name: 'WordPress Author',
              slug: 'wp-author'
            }
          },
          categories: {
            nodes: []
          },
          tags: {
            nodes: []
          }
        }
      }
    }
  } catch (error) {
    console.log('WordPress REST API not available, trying GraphQL...')
  }

  try {
    const { data } = await client.query({
      query: GET_POST_BY_SLUG,
      variables: { slug },
      errorPolicy: 'all'
    })
    return data?.postBy || mockPosts.find(post => post.slug === slug) || null
  } catch (error) {
    console.error(`Error fetching post with slug ${slug}, falling back to mock data:`, error)
    return mockPosts.find(post => post.slug === slug) || null
  }
}

export async function getAllPages() {
  try {
    const { data } = await client.query({
      query: GET_ALL_PAGES,
      errorPolicy: 'all'
    })
    return data?.pages?.nodes || []
  } catch (error) {
    console.error('Error fetching pages:', error)
    return []
  }
}

export async function getSiteSettings() {
  // Check if WordPress backend is available
  const wordpressUrl = process.env.WORDPRESS_GRAPHQL_URL || process.env.NEXT_PUBLIC_WORDPRESS_API_URL
  
  if (!wordpressUrl || wordpressUrl.includes('localhost')) {
    console.log('WordPress backend not available, using mock site settings')
    return mockSiteSettings
  }

  try {
    const { data } = await client.query({
      query: GET_SITE_SETTINGS,
      errorPolicy: 'all'
    })
    return data?.generalSettings || mockSiteSettings
  } catch (error) {
    console.error('Error fetching site settings, falling back to mock data:', error)
    return mockSiteSettings
  }
}

// TypeScript interfaces
export interface Post {
  id: string
  slug: string
  title: string
  content: string
  excerpt: string
  date: string
  modified: string
  featuredImage?: {
    node: {
      sourceUrl: string
      altText: string
      title: string
    }
  }
  author: {
    node: {
      name: string
      slug: string
    }
  }
  categories: {
    nodes: Array<{
      name: string
      slug: string
    }>
  }
  tags: {
    nodes: Array<{
      name: string
      slug: string
    }>
  }
}

export interface Page {
  id: string
  slug: string
  title: string
  content: string
  modified: string
}

export interface SiteSettings {
  title: string
  description: string
  url: string
}
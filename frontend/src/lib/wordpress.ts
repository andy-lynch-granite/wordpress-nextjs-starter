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

// Helper functions for static generation
export async function getAllPosts() {
  try {
    const { data } = await client.query({
      query: GET_ALL_POSTS,
      errorPolicy: 'all'
    })
    return data?.posts?.nodes || []
  } catch (error) {
    console.error('Error fetching posts:', error)
    return []
  }
}

export async function getPostBySlug(slug: string) {
  try {
    const { data } = await client.query({
      query: GET_POST_BY_SLUG,
      variables: { slug },
      errorPolicy: 'all'
    })
    return data?.postBy || null
  } catch (error) {
    console.error(`Error fetching post with slug ${slug}:`, error)
    return null
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
  try {
    const { data } = await client.query({
      query: GET_SITE_SETTINGS,
      errorPolicy: 'all'
    })
    return data?.generalSettings || {}
  } catch (error) {
    console.error('Error fetching site settings:', error)
    return {}
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
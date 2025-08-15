import Link from 'next/link'
import { getAllPosts, getSiteSettings, Post, SiteSettings } from '@/lib/wordpress'

interface BlogPageProps {
  posts: Post[]
  siteSettings: SiteSettings
}

// Static generation - fetch data at build time
export default async function BlogPage() {
  const [posts, siteSettings] = await Promise.all([
    getAllPosts(),
    getSiteSettings()
  ])

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 py-8">
        <header className="mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            {siteSettings.title ? `${siteSettings.title} - Blog` : 'Blog'}
          </h1>
          {siteSettings.description && (
            <p className="text-lg text-gray-600">{siteSettings.description}</p>
          )}
        </header>

        <div className="space-y-8">
          {posts.length > 0 ? (
            posts.map((post: Post) => (
              <article
                key={post.id}
                className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow"
              >
                <h2 className="text-2xl font-semibold text-gray-900 mb-3">
                  <Link 
                    href={`/blog/${post.slug}/`}
                    className="hover:text-blue-600 transition-colors"
                  >
                    {post.title}
                  </Link>
                </h2>
                
                <div className="text-sm text-gray-500 mb-4">
                  <time dateTime={post.date}>
                    {new Date(post.date).toLocaleDateString('en-US', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric'
                    })}
                  </time>
                  {post.author?.node?.name && (
                    <span> • by {post.author.node.name}</span>
                  )}
                </div>

                {post.excerpt && (
                  <div 
                    className="text-gray-700 mb-4"
                    dangerouslySetInnerHTML={{ __html: post.excerpt }}
                  />
                )}

                {post.categories?.nodes && post.categories.nodes.length > 0 && (
                  <div className="flex flex-wrap gap-2 mb-4">
                    {post.categories.nodes.map((category: { name: string; slug: string }) => (
                      <span
                        key={category.slug}
                        className="px-3 py-1 bg-blue-100 text-blue-800 text-sm rounded-full"
                      >
                        {category.name}
                      </span>
                    ))}
                  </div>
                )}

                <Link 
                  href={`/blog/${post.slug}/`}
                  className="inline-flex items-center text-blue-600 hover:text-blue-800 font-medium"
                >
                  Read more
                  <svg className="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </Link>
              </article>
            ))
          ) : (
            <div className="text-center py-12">
              <p className="text-gray-500 text-lg">No posts found.</p>
            </div>
          )}
        </div>

        <footer className="mt-12 pt-8 border-t border-gray-200">
          <Link 
            href="/"
            className="inline-flex items-center text-blue-600 hover:text-blue-800 font-medium"
          >
            <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            Back to Home
          </Link>
        </footer>
      </div>
    </div>
  )
}

// Metadata for SEO
export async function generateMetadata() {
  const siteSettings = await getSiteSettings()
  
  return {
    title: siteSettings.title ? `${siteSettings.title} - Blog` : 'Blog',
    description: siteSettings.description || 'Latest blog posts',
  }
}
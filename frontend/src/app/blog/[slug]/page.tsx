import Link from 'next/link'
import { notFound } from 'next/navigation'
import { getAllPosts, getPostBySlug, Post } from '@/lib/wordpress'

interface BlogPostPageProps {
  params: {
    slug: string
  }
}

// Static generation - generate all post pages at build time
export async function generateStaticParams() {
  const posts = await getAllPosts()
  
  return posts.map((post: Post) => ({
    slug: post.slug,
  }))
}

// Generate metadata for SEO
export async function generateMetadata({ params }: BlogPostPageProps) {
  const post = await getPostBySlug(params.slug)
  
  if (!post) {
    return {
      title: 'Post Not Found',
    }
  }
  
  return {
    title: post.title,
    description: post.excerpt ? post.excerpt.replace(/<[^>]*>/g, '').substring(0, 160) : undefined,
  }
}

export default async function BlogPostPage({ params }: BlogPostPageProps) {
  const post = await getPostBySlug(params.slug)
  
  if (!post) {
    notFound()
  }
  
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 py-8">
        {/* Navigation */}
        <nav className="mb-8">
          <Link 
            href="/blog/"
            className="inline-flex items-center text-blue-600 hover:text-blue-800 font-medium"
          >
            <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            Back to Blog
          </Link>
        </nav>

        {/* Article */}
        <article className="bg-white rounded-lg shadow-md overflow-hidden">
          {/* Featured Image */}
          {post.featuredImage?.node?.sourceUrl && (
            <div className="w-full h-64 md:h-80 bg-gray-200">
              <img
                src={post.featuredImage.node.sourceUrl}
                alt={post.featuredImage.node.altText || post.title}
                className="w-full h-full object-cover"
              />
            </div>
          )}

          <div className="p-8">
            {/* Header */}
            <header className="mb-8">
              <h1 className="text-4xl font-bold text-gray-900 mb-4">
                {post.title}
              </h1>
              
              <div className="flex flex-wrap items-center gap-4 text-sm text-gray-500">
                <time dateTime={post.date}>
                  Published {new Date(post.date).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })}
                </time>
                
                {post.author?.node?.name && (
                  <span>by {post.author.node.name}</span>
                )}
                
                {post.modified !== post.date && (
                  <span>
                    Updated {new Date(post.modified).toLocaleDateString('en-US', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric'
                    })}
                  </span>
                )}
              </div>

              {/* Categories */}
              {post.categories?.nodes && post.categories.nodes.length > 0 && (
                <div className="flex flex-wrap gap-2 mt-4">
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
            </header>

            {/* Content */}
            <div 
              className="prose prose-lg max-w-none"
              dangerouslySetInnerHTML={{ __html: post.content }}
            />

            {/* Tags */}
            {post.tags?.nodes && post.tags.nodes.length > 0 && (
              <footer className="mt-8 pt-8 border-t border-gray-200">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Tags</h3>
                <div className="flex flex-wrap gap-2">
                  {post.tags.nodes.map((tag: { name: string; slug: string }) => (
                    <span
                      key={tag.slug}
                      className="px-3 py-1 bg-gray-100 text-gray-700 text-sm rounded-full"
                    >
                      #{tag.name}
                    </span>
                  ))}
                </div>
              </footer>
            )}
          </div>
        </article>

        {/* Navigation Footer */}
        <footer className="mt-8">
          <Link 
            href="/blog/"
            className="inline-flex items-center text-blue-600 hover:text-blue-800 font-medium"
          >
            <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            Back to Blog
          </Link>
        </footer>
      </div>
    </div>
  )
}
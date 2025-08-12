export default function HomePage() {
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-4 py-8">
        <header className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Headless WordPress + Next.js
          </h1>
          <p className="text-xl text-gray-600">
            A modern starter kit for headless WordPress development
          </p>
        </header>

        <main className="max-w-4xl mx-auto">
          <div className="grid md:grid-cols-2 gap-8">
            <div className="bg-white p-6 rounded-lg shadow-md">
              <h2 className="text-2xl font-semibold mb-4">WordPress Backend</h2>
              <p className="text-gray-600 mb-4">
                Headless WordPress with GraphQL API running on port 8081
              </p>
              <a
                href="http://localhost:8081"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-block bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 transition-colors"
              >
                Open WordPress Admin
              </a>
            </div>

            <div className="bg-white p-6 rounded-lg shadow-md">
              <h2 className="text-2xl font-semibold mb-4">Next.js Frontend</h2>
              <p className="text-gray-600 mb-4">
                Modern React frontend with static site generation
              </p>
              <div className="space-y-2">
                <a
                  href="/blog"
                  className="block text-blue-500 hover:text-blue-600"
                >
                  → View Blog Posts
                </a>
                <a
                  href="/about"
                  className="block text-blue-500 hover:text-blue-600"
                >
                  → About Page
                </a>
              </div>
            </div>
          </div>

          <div className="mt-12 bg-white p-6 rounded-lg shadow-md">
            <h2 className="text-2xl font-semibold mb-4">API Status</h2>
            <div className="grid md:grid-cols-3 gap-4">
              <div className="text-center">
                <div className="w-4 h-4 bg-green-500 rounded-full mx-auto mb-2"></div>
                <p className="font-medium">WordPress</p>
                <p className="text-sm text-gray-600">Running</p>
              </div>
              <div className="text-center">
                <div className="w-4 h-4 bg-green-500 rounded-full mx-auto mb-2"></div>
                <p className="font-medium">GraphQL API</p>
                <p className="text-sm text-gray-600">Available</p>
              </div>
              <div className="text-center">
                <div className="w-4 h-4 bg-green-500 rounded-full mx-auto mb-2"></div>
                <p className="font-medium">REST API</p>
                <p className="text-sm text-gray-600">Available</p>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}
export default function HomePage() {
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-4 py-8">
        <header className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Headless WordPress + Next.js
          </h1>
          <p className="text-xl text-gray-600">
            A modern starter kit deployed on Azure with CI/CD pipeline
          </p>
          <div className="mt-4 inline-block bg-green-100 text-green-800 px-4 py-2 rounded-full">
            ✅ Deployed to Azure Static Hosting
          </div>
        </header>

        <main className="max-w-4xl mx-auto">
          <div className="grid md:grid-cols-2 gap-8">
            <div className="bg-white p-6 rounded-lg shadow-md">
              <h2 className="text-2xl font-semibold mb-4">WordPress Backend</h2>
              <p className="text-gray-600 mb-4">
                Headless WordPress with GraphQL API - ready for Azure Container Apps deployment
              </p>
              <div className="text-sm text-orange-600 bg-orange-50 p-3 rounded">
                🚧 Backend deployment coming next
              </div>
            </div>

            <div className="bg-white p-6 rounded-lg shadow-md">
              <h2 className="text-2xl font-semibold mb-4">Next.js Frontend</h2>
              <p className="text-gray-600 mb-4">
                Modern React frontend deployed via GitHub Actions to Azure Storage
              </p>
              <div className="space-y-2">
                <div className="text-sm text-green-600 bg-green-50 p-3 rounded">
                  ✅ CI/CD Pipeline Active
                </div>
                <div className="text-sm text-blue-600 bg-blue-50 p-3 rounded mt-2">
                  📦 Static hosting on Azure Storage
                </div>
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
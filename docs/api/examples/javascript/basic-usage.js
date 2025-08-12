/**
 * JavaScript/Node.js API Usage Examples
 * 
 * This file demonstrates how to interact with our headless WordPress API
 * using both REST and GraphQL endpoints in JavaScript/Node.js applications.
 */

// =============================================================================
// SETUP AND CONFIGURATION
// =============================================================================

const API_BASE_URL = 'https://your-domain.com';
const GRAPHQL_ENDPOINT = `${API_BASE_URL}/graphql`;
const REST_BASE_URL = `${API_BASE_URL}/wp-json/wp/v2`;

// Authentication configuration
let authToken = null;

/**
 * Set authentication token for API requests
 * @param {string} token - JWT token
 */
function setAuthToken(token) {
    authToken = token;
}

/**
 * Get authentication headers
 * @returns {Object} Headers object
 */
function getAuthHeaders() {
    const headers = {
        'Content-Type': 'application/json',
    };
    
    if (authToken) {
        headers['Authorization'] = `Bearer ${authToken}`;
    }
    
    return headers;
}

// =============================================================================
// AUTHENTICATION EXAMPLES
// =============================================================================

/**
 * Authenticate and get JWT token
 * @param {string} username - WordPress username
 * @param {string} password - WordPress password
 * @returns {Promise<string>} JWT token
 */
async function authenticate(username, password) {
    try {
        const response = await fetch(`${API_BASE_URL}/wp-json/jwt-auth/v1/token`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                username,
                password,
            }),
        });

        if (!response.ok) {
            throw new Error(`Authentication failed: ${response.statusText}`);
        }

        const data = await response.json();
        authToken = data.token;
        
        console.log('Authentication successful!');
        console.log('User:', data.user_display_name);
        console.log('Email:', data.user_email);
        
        return data.token;
    } catch (error) {
        console.error('Authentication error:', error);
        throw error;
    }
}

/**
 * Validate current JWT token
 * @returns {Promise<boolean>} Token validity
 */
async function validateToken() {
    if (!authToken) {
        console.log('No token to validate');
        return false;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/wp-json/jwt-auth/v1/token/validate`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
            },
        });

        return response.ok;
    } catch (error) {
        console.error('Token validation error:', error);
        return false;
    }
}

// =============================================================================
// GRAPHQL API EXAMPLES
// =============================================================================

/**
 * Execute GraphQL query
 * @param {string} query - GraphQL query string
 * @param {Object} variables - Query variables
 * @returns {Promise<Object>} Query result
 */
async function executeGraphQLQuery(query, variables = {}) {
    try {
        const response = await fetch(GRAPHQL_ENDPOINT, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: JSON.stringify({
                query,
                variables,
            }),
        });

        if (!response.ok) {
            throw new Error(`GraphQL request failed: ${response.statusText}`);
        }

        const result = await response.json();
        
        if (result.errors) {
            console.error('GraphQL errors:', result.errors);
            throw new Error('GraphQL query failed');
        }

        return result.data;
    } catch (error) {
        console.error('GraphQL error:', error);
        throw error;
    }
}

/**
 * Get all posts using GraphQL
 * @param {number} first - Number of posts to fetch
 * @param {string} after - Cursor for pagination
 * @returns {Promise<Object>} Posts data
 */
async function getPostsGraphQL(first = 10, after = null) {
    const query = `
        query GetPosts($first: Int!, $after: String) {
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
                        databaseId
                        title
                        excerpt
                        slug
                        date
                        modified
                        status
                        author {
                            node {
                                name
                                email
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

    const variables = { first };
    if (after) variables.after = after;

    return await executeGraphQLQuery(query, variables);
}

/**
 * Get single post by slug using GraphQL
 * @param {string} slug - Post slug
 * @returns {Promise<Object>} Post data
 */
async function getPostBySlugGraphQL(slug) {
    const query = `
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
                status
                author {
                    node {
                        name
                        email
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
                seo {
                    title
                    metaDesc
                    opengraphImage {
                        sourceUrl
                    }
                }
            }
        }
    `;

    const result = await executeGraphQLQuery(query, { slug });
    return result.post;
}

/**
 * Create new post using GraphQL
 * @param {Object} postData - Post data
 * @returns {Promise<Object>} Created post
 */
async function createPostGraphQL(postData) {
    const mutation = `
        mutation CreatePost($input: CreatePostInput!) {
            createPost(input: $input) {
                post {
                    id
                    databaseId
                    title
                    content
                    slug
                    status
                    date
                    author {
                        node {
                            name
                        }
                    }
                }
                clientMutationId
            }
        }
    `;

    const input = {
        title: postData.title,
        content: postData.content,
        status: postData.status || 'DRAFT',
        excerpt: postData.excerpt || '',
    };

    if (postData.categories) {
        input.categories = { append: postData.categories };
    }

    if (postData.tags) {
        input.tags = { append: postData.tags };
    }

    const result = await executeGraphQLQuery(mutation, { input });
    return result.createPost.post;
}

/**
 * Search content using GraphQL
 * @param {string} searchTerm - Search query
 * @param {Array} contentTypes - Content types to search
 * @returns {Promise<Array>} Search results
 */
async function searchContentGraphQL(searchTerm, contentTypes = ['POST', 'PAGE']) {
    const query = `
        query SearchContent($searchTerm: String!, $contentTypes: [ContentTypeEnum!]) {
            contentNodes(
                where: {
                    search: $searchTerm,
                    contentTypes: $contentTypes
                }
            ) {
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

    const result = await executeGraphQLQuery(query, { searchTerm, contentTypes });
    return result.contentNodes.nodes;
}

// =============================================================================
// REST API EXAMPLES
// =============================================================================

/**
 * Execute REST API request
 * @param {string} endpoint - API endpoint
 * @param {Object} options - Fetch options
 * @returns {Promise<Object>} Response data
 */
async function executeRESTRequest(endpoint, options = {}) {
    const url = endpoint.startsWith('http') ? endpoint : `${REST_BASE_URL}${endpoint}`;
    
    const defaultOptions = {
        headers: getAuthHeaders(),
    };

    const finalOptions = { ...defaultOptions, ...options };
    
    // Merge headers properly
    if (options.headers) {
        finalOptions.headers = { ...defaultOptions.headers, ...options.headers };
    }

    try {
        const response = await fetch(url, finalOptions);

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(`REST request failed: ${response.statusText} - ${errorData.message || ''}`);
        }

        return await response.json();
    } catch (error) {
        console.error('REST API error:', error);
        throw error;
    }
}

/**
 * Get all posts using REST API
 * @param {Object} params - Query parameters
 * @returns {Promise<Array>} Posts array
 */
async function getPostsREST(params = {}) {
    const queryParams = new URLSearchParams({
        per_page: 10,
        _embed: true, // Include embedded data (author, media, etc.)
        ...params,
    });

    return await executeRESTRequest(`/posts?${queryParams}`);
}

/**
 * Get single post by ID using REST API
 * @param {number} postId - Post ID
 * @returns {Promise<Object>} Post data
 */
async function getPostByIdREST(postId) {
    return await executeRESTRequest(`/posts/${postId}?_embed=true`);
}

/**
 * Get post by slug using REST API
 * @param {string} slug - Post slug
 * @returns {Promise<Object>} Post data
 */
async function getPostBySlugREST(slug) {
    const posts = await executeRESTRequest(`/posts?slug=${slug}&_embed=true`);
    return posts.length > 0 ? posts[0] : null;
}

/**
 * Create new post using REST API
 * @param {Object} postData - Post data
 * @returns {Promise<Object>} Created post
 */
async function createPostREST(postData) {
    return await executeRESTRequest('/posts', {
        method: 'POST',
        body: JSON.stringify({
            title: postData.title,
            content: postData.content,
            status: postData.status || 'draft',
            excerpt: postData.excerpt || '',
            categories: postData.categories || [],
            tags: postData.tags || [],
            featured_media: postData.featured_media || null,
        }),
    });
}

/**
 * Update post using REST API
 * @param {number} postId - Post ID
 * @param {Object} updateData - Update data
 * @returns {Promise<Object>} Updated post
 */
async function updatePostREST(postId, updateData) {
    return await executeRESTRequest(`/posts/${postId}`, {
        method: 'PUT',
        body: JSON.stringify(updateData),
    });
}

/**
 * Delete post using REST API
 * @param {number} postId - Post ID
 * @param {boolean} force - Force delete (bypass trash)
 * @returns {Promise<Object>} Deletion result
 */
async function deletePostREST(postId, force = false) {
    const params = force ? '?force=true' : '';
    return await executeRESTRequest(`/posts/${postId}${params}`, {
        method: 'DELETE',
    });
}

/**
 * Upload media file using REST API
 * @param {File|Buffer} file - File to upload
 * @param {string} filename - File name
 * @param {string} caption - File caption
 * @returns {Promise<Object>} Media data
 */
async function uploadMediaREST(file, filename, caption = '') {
    const formData = new FormData();
    formData.append('file', file, filename);
    
    if (caption) {
        formData.append('caption', caption);
    }

    const headers = {};
    if (authToken) {
        headers['Authorization'] = `Bearer ${authToken}`;
    }

    return await executeRESTRequest('/media', {
        method: 'POST',
        headers,
        body: formData,
    });
}

/**
 * Get categories using REST API
 * @param {Object} params - Query parameters
 * @returns {Promise<Array>} Categories array
 */
async function getCategoriesREST(params = {}) {
    const queryParams = new URLSearchParams({
        per_page: 100,
        ...params,
    });

    return await executeRESTRequest(`/categories?${queryParams}`);
}

/**
 * Get tags using REST API
 * @param {Object} params - Query parameters
 * @returns {Promise<Array>} Tags array
 */
async function getTagsREST(params = {}) {
    const queryParams = new URLSearchParams({
        per_page: 100,
        ...params,
    });

    return await executeRESTRequest(`/tags?${queryParams}`);
}

// =============================================================================
// USAGE EXAMPLES
// =============================================================================

/**
 * Example usage of the API functions
 */
async function exampleUsage() {
    try {
        // Authentication
        console.log('=== Authentication Example ===');
        await authenticate('username', 'password');
        
        // Validate token
        const isValid = await validateToken();
        console.log('Token valid:', isValid);

        // GraphQL Examples
        console.log('\n=== GraphQL Examples ===');
        
        // Get posts with GraphQL
        const graphqlPosts = await getPostsGraphQL(5);
        console.log('GraphQL Posts:', graphqlPosts.posts.edges.length);
        
        // Get single post by slug
        if (graphqlPosts.posts.edges.length > 0) {
            const firstPost = graphqlPosts.posts.edges[0].node;
            const singlePost = await getPostBySlugGraphQL(firstPost.slug);
            console.log('Single Post Title:', singlePost.title);
        }
        
        // Search content
        const searchResults = await searchContentGraphQL('technology');
        console.log('Search Results:', searchResults.length);

        // REST API Examples
        console.log('\n=== REST API Examples ===');
        
        // Get posts with REST
        const restPosts = await getPostsREST({ per_page: 5 });
        console.log('REST Posts:', restPosts.length);
        
        // Get categories
        const categories = await getCategoriesREST();
        console.log('Categories:', categories.length);
        
        // Get tags
        const tags = await getTagsREST();
        console.log('Tags:', tags.length);

        // Create new post (requires authentication)
        if (authToken) {
            console.log('\n=== Create Post Example ===');
            
            const newPostData = {
                title: 'Test Post from API',
                content: '<p>This is a test post created via API.</p>',
                excerpt: 'A test post created using our API examples.',
                status: 'draft',
                categories: categories.slice(0, 2).map(cat => cat.id),
                tags: tags.slice(0, 3).map(tag => tag.id),
            };
            
            // Create with GraphQL
            const graphqlPost = await createPostGraphQL(newPostData);
            console.log('Created GraphQL Post:', graphqlPost.title);
            
            // Create with REST
            const restPost = await createPostREST(newPostData);
            console.log('Created REST Post:', restPost.title.rendered);
        }

    } catch (error) {
        console.error('Example usage error:', error);
    }
}

/**
 * Pagination example with GraphQL
 */
async function paginationExample() {
    console.log('=== Pagination Example ===');
    
    let hasNextPage = true;
    let after = null;
    let pageCount = 0;
    
    while (hasNextPage && pageCount < 3) { // Limit to 3 pages for demo
        pageCount++;
        console.log(`\nFetching page ${pageCount}...`);
        
        const result = await getPostsGraphQL(5, after);
        const { pageInfo, edges } = result.posts;
        
        console.log(`Page ${pageCount}: ${edges.length} posts`);
        edges.forEach((edge, index) => {
            console.log(`  ${index + 1}. ${edge.node.title}`);
        });
        
        hasNextPage = pageInfo.hasNextPage;
        after = pageInfo.endCursor;
    }
}

/**
 * Error handling example
 */
async function errorHandlingExample() {
    console.log('=== Error Handling Example ===');
    
    try {
        // This should fail - invalid post ID
        await getPostByIdREST(999999);
    } catch (error) {
        console.log('Expected error caught:', error.message);
    }
    
    try {
        // This should fail - invalid GraphQL query
        await executeGraphQLQuery('query { invalidField }');
    } catch (error) {
        console.log('GraphQL error caught:', error.message);
    }
}

// =============================================================================
// EXPORT FOR MODULE USAGE
// =============================================================================

// For Node.js module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        // Authentication
        authenticate,
        validateToken,
        setAuthToken,
        
        // GraphQL
        executeGraphQLQuery,
        getPostsGraphQL,
        getPostBySlugGraphQL,
        createPostGraphQL,
        searchContentGraphQL,
        
        // REST API
        executeRESTRequest,
        getPostsREST,
        getPostByIdREST,
        getPostBySlugREST,
        createPostREST,
        updatePostREST,
        deletePostREST,
        uploadMediaREST,
        getCategoriesREST,
        getTagsREST,
        
        // Examples
        exampleUsage,
        paginationExample,
        errorHandlingExample,
    };
}

// For browser usage, functions are available globally
if (typeof window !== 'undefined') {
    window.WordPressAPI = {
        authenticate,
        validateToken,
        setAuthToken,
        executeGraphQLQuery,
        getPostsGraphQL,
        getPostBySlugGraphQL,
        createPostGraphQL,
        searchContentGraphQL,
        executeRESTRequest,
        getPostsREST,
        getPostByIdREST,
        getPostBySlugREST,
        createPostREST,
        updatePostREST,
        deletePostREST,
        uploadMediaREST,
        getCategoriesREST,
        getTagsREST,
    };
}

// Run examples if this file is executed directly
if (typeof require !== 'undefined' && require.main === module) {
    exampleUsage()
        .then(() => paginationExample())
        .then(() => errorHandlingExample())
        .catch(console.error);
}
# Automated API Documentation

## Overview

This document outlines our automated documentation generation system for the headless WordPress + Next.js API. Our automation ensures that API documentation stays current with code changes, reduces manual maintenance overhead, and provides developers with always up-to-date information.

## Automation Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Source Code Changes                     │
│                 (GraphQL Schema, REST)                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                GitHub Actions Workflow                     │
│            (Triggered on code changes)                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼─────┐  ┌────▼─────┐  ┌───▼────────┐
│   Schema    │  │   REST   │  │ Examples   │
│ Generation  │  │ Analysis │  │ Validation │
│             │  │          │  │            │
└─────────────┘  └──────────┘  └────────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Documentation Update                          │
│         (Markdown files, Confluence sync)                  │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. GraphQL Schema Generation

#### Schema Introspection Tool

`scripts/generate-graphql-docs.js`:

```javascript
#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { buildClientSchema, getIntrospectionQuery, printSchema } = require('graphql');
const fetch = require('node-fetch');

// Configuration
const GRAPHQL_ENDPOINT = process.env.GRAPHQL_ENDPOINT || 'http://localhost:8080/graphql';
const OUTPUT_DIR = './docs/api/graphql/schema';

/**
 * Fetch GraphQL schema via introspection
 */
async function fetchSchema() {
    console.log('📡 Fetching GraphQL schema...');
    
    const introspectionQuery = getIntrospectionQuery();
    
    try {
        const response = await fetch(GRAPHQL_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                query: introspectionQuery,
            }),
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        
        if (result.errors) {
            throw new Error(`GraphQL errors: ${JSON.stringify(result.errors)}`);
        }

        return result.data;
    } catch (error) {
        console.error('❌ Failed to fetch schema:', error);
        process.exit(1);
    }
}

/**
 * Generate type documentation
 */
function generateTypeDocumentation(schema) {
    console.log('📝 Generating type documentation...');
    
    const typeMap = schema.getTypeMap();
    const types = Object.values(typeMap).filter(type => 
        !type.name.startsWith('_') && // Skip introspection types
        !['String', 'Int', 'Float', 'Boolean', 'ID'].includes(type.name) // Skip scalars
    );

    let typesDocs = `# GraphQL Types Reference

This document contains all custom types available in our GraphQL schema.

## Overview

The GraphQL schema defines ${types.length} custom types for content management and API operations.

## Type Definitions

`;

    types.forEach(type => {
        typesDocs += `### ${type.name}\n\n`;
        
        if (type.description) {
            typesDocs += `${type.description}\n\n`;
        }

        typesDocs += '```graphql\n';
        typesDocs += printSchema(buildClientSchema({ __schema: schema }))
            .split('\n')
            .filter(line => line.includes(type.name) || line.startsWith('  '))
            .join('\n');
        typesDocs += '\n```\n\n';

        // Add field descriptions if available
        if (type.getFields) {
            const fields = type.getFields();
            const fieldNames = Object.keys(fields);
            
            if (fieldNames.length > 0) {
                typesDocs += '#### Fields\n\n';
                typesDocs += '| Field | Type | Description |\n';
                typesDocs += '|-------|------|--------------|\n';
                
                fieldNames.forEach(fieldName => {
                    const field = fields[fieldName];
                    const fieldType = field.type.toString();
                    const description = field.description || 'No description available';
                    typesDocs += `| \`${fieldName}\` | \`${fieldType}\` | ${description} |\n`;
                });
                
                typesDocs += '\n';
            }
        }

        typesDocs += '---\n\n';
    });

    return typesDocs;
}

/**
 * Generate queries documentation
 */
function generateQueriesDocumentation(schema) {
    console.log('📝 Generating queries documentation...');
    
    const queryType = schema.getQueryType();
    if (!queryType) return '';

    const queries = queryType.getFields();
    const queryNames = Object.keys(queries);

    let queriesDocs = `# GraphQL Queries Reference

This document contains all available queries in our GraphQL API.

## Available Queries (${queryNames.length})

`;

    queryNames.forEach(queryName => {
        const query = queries[queryName];
        queriesDocs += `### ${queryName}\n\n`;
        
        if (query.description) {
            queriesDocs += `${query.description}\n\n`;
        }

        queriesDocs += '**Type:** `' + query.type.toString() + '`\n\n';

        // Add arguments if available
        if (query.args && query.args.length > 0) {
            queriesDocs += '**Arguments:**\n\n';
            queriesDocs += '| Argument | Type | Required | Description |\n';
            queriesDocs += '|----------|------|---------|--------------|\n';
            
            query.args.forEach(arg => {
                const isRequired = arg.type.toString().endsWith('!');
                const description = arg.description || 'No description available';
                queriesDocs += `| \`${arg.name}\` | \`${arg.type}\` | ${isRequired ? 'Yes' : 'No'} | ${description} |\n`;
            });
            
            queriesDocs += '\n';
        }

        // Add example query
        queriesDocs += '**Example:**\n\n';
        queriesDocs += '```graphql\n';
        queriesDocs += `query {\n  ${queryName}`;
        
        if (query.args && query.args.length > 0) {
            const requiredArgs = query.args.filter(arg => arg.type.toString().endsWith('!'));
            if (requiredArgs.length > 0) {
                queriesDocs += '(';
                queriesDocs += requiredArgs.map(arg => {
                    const exampleValue = getExampleValue(arg.type.toString());
                    return `${arg.name}: ${exampleValue}`;
                }).join(', ');
                queriesDocs += ')';
            }
        }
        
        queriesDocs += ' {\n    # Add fields here\n  }\n}\n```\n\n';
        queriesDocs += '---\n\n';
    });

    return queriesDocs;
}

/**
 * Get example value for a GraphQL type
 */
function getExampleValue(type) {
    const cleanType = type.replace(/[!\[\]]/g, '');
    
    switch (cleanType) {
        case 'String': return '"example"';
        case 'Int': return '10';
        case 'Float': return '10.5';
        case 'Boolean': return 'true';
        case 'ID': return '"abc123"';
        default: return `"${cleanType}_example"`;
    }
}

/**
 * Generate mutations documentation
 */
function generateMutationsDocumentation(schema) {
    console.log('📝 Generating mutations documentation...');
    
    const mutationType = schema.getMutationType();
    if (!mutationType) return '';

    const mutations = mutationType.getFields();
    const mutationNames = Object.keys(mutations);

    let mutationsDocs = `# GraphQL Mutations Reference

This document contains all available mutations in our GraphQL API.

## Available Mutations (${mutationNames.length})

`;

    mutationNames.forEach(mutationName => {
        const mutation = mutations[mutationName];
        mutationsDocs += `### ${mutationName}\n\n`;
        
        if (mutation.description) {
            mutationsDocs += `${mutation.description}\n\n`;
        }

        mutationsDocs += '**Return Type:** `' + mutation.type.toString() + '`\n\n';

        // Add arguments
        if (mutation.args && mutation.args.length > 0) {
            mutationsDocs += '**Arguments:**\n\n';
            mutationsDocs += '| Argument | Type | Required | Description |\n';
            mutationsDocs += '|----------|------|---------|--------------|\n';
            
            mutation.args.forEach(arg => {
                const isRequired = arg.type.toString().endsWith('!');
                const description = arg.description || 'No description available';
                mutationsDocs += `| \`${arg.name}\` | \`${arg.type}\` | ${isRequired ? 'Yes' : 'No'} | ${description} |\n`;
            });
            
            mutationsDocs += '\n';
        }

        // Add example mutation
        mutationsDocs += '**Example:**\n\n';
        mutationsDocs += '```graphql\n';
        mutationsDocs += `mutation {\n  ${mutationName}`;
        
        if (mutation.args && mutation.args.length > 0) {
            mutationsDocs += '(\n';
            mutation.args.forEach((arg, index) => {
                const exampleValue = getExampleValue(arg.type.toString());
                mutationsDocs += `    ${arg.name}: ${exampleValue}`;
                if (index < mutation.args.length - 1) mutationsDocs += ',';
                mutationsDocs += '\n';
            });
            mutationsDocs += '  )';
        }
        
        mutationsDocs += ' {\n    # Add return fields here\n  }\n}\n```\n\n';
        mutationsDocs += '---\n\n';
    });

    return mutationsDocs;
}

/**
 * Main execution function
 */
async function main() {
    console.log('🚀 Starting GraphQL documentation generation...');

    // Ensure output directory exists
    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    // Fetch schema
    const introspectionResult = await fetchSchema();
    const schema = buildClientSchema(introspectionResult);

    // Generate documentation files
    const typesDocs = generateTypeDocumentation(schema);
    const queriesDocs = generateQueriesDocumentation(schema);
    const mutationsDocs = generateMutationsDocumentation(schema);

    // Write files
    fs.writeFileSync(path.join(OUTPUT_DIR, 'types.md'), typesDocs);
    fs.writeFileSync(path.join(OUTPUT_DIR, 'queries.md'), queriesDocs);
    fs.writeFileSync(path.join(OUTPUT_DIR, 'mutations.md'), mutationsDocs);

    // Generate schema.graphql file
    const schemaSDL = printSchema(schema);
    fs.writeFileSync(path.join(OUTPUT_DIR, 'schema.graphql'), schemaSDL);

    console.log('✅ GraphQL documentation generated successfully!');
    console.log(`📁 Output directory: ${OUTPUT_DIR}`);
    console.log('📄 Generated files:');
    console.log('  - types.md');
    console.log('  - queries.md');
    console.log('  - mutations.md');
    console.log('  - schema.graphql');
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

module.exports = {
    fetchSchema,
    generateTypeDocumentation,
    generateQueriesDocumentation,
    generateMutationsDocumentation,
};
```

### 2. REST API Analysis

#### REST Endpoint Discovery

`scripts/analyze-rest-endpoints.js`:

```javascript
#!/usr/bin/env node

const fetch = require('node-fetch');
const fs = require('fs');
const path = require('path');

// Configuration
const WP_BASE_URL = process.env.WP_BASE_URL || 'http://localhost:8080';
const REST_API_BASE = `${WP_BASE_URL}/wp-json`;
const OUTPUT_DIR = './docs/api/rest';

/**
 * Discover all available REST endpoints
 */
async function discoverEndpoints() {
    console.log('🔍 Discovering REST API endpoints...');
    
    try {
        const response = await fetch(REST_API_BASE);
        const data = await response.json();
        
        const endpoints = [];
        
        // Parse namespace information
        Object.keys(data.namespaces || {}).forEach(namespace => {
            const namespaceData = data.namespaces[namespace];
            
            if (namespaceData.routes) {
                Object.keys(namespaceData.routes).forEach(route => {
                    const routeData = namespaceData.routes[route];
                    endpoints.push({
                        namespace,
                        route,
                        methods: routeData.methods || [],
                        endpoints: routeData.endpoints || [],
                    });
                });
            }
        });
        
        return endpoints;
    } catch (error) {
        console.error('❌ Failed to discover endpoints:', error);
        return [];
    }
}

/**
 * Generate endpoint documentation
 */
function generateEndpointDocs(endpoints) {
    console.log('📝 Generating REST endpoint documentation...');
    
    const groupedEndpoints = {};
    
    // Group endpoints by namespace
    endpoints.forEach(endpoint => {
        if (!groupedEndpoints[endpoint.namespace]) {
            groupedEndpoints[endpoint.namespace] = [];
        }
        groupedEndpoints[endpoint.namespace].push(endpoint);
    });
    
    let docs = `# REST API Endpoints Reference

This document contains all available REST API endpoints.

## Discovered Endpoints

Total endpoints: ${endpoints.length}

`;

    Object.keys(groupedEndpoints).forEach(namespace => {
        docs += `## ${namespace}\n\n`;
        
        const namespaceEndpoints = groupedEndpoints[namespace];
        
        docs += '| Endpoint | Methods | Description |\n';
        docs += '|----------|---------|-------------|\n';
        
        namespaceEndpoints.forEach(endpoint => {
            const methods = endpoint.methods.join(', ');
            docs += `| \`${endpoint.route}\` | ${methods} | Auto-discovered endpoint |\n`;
        });
        
        docs += '\n';
    });
    
    return docs;
}

/**
 * Analyze endpoint schemas
 */
async function analyzeEndpointSchemas() {
    console.log('🔬 Analyzing endpoint schemas...');
    
    const commonEndpoints = [
        '/wp/v2/posts',
        '/wp/v2/pages',
        '/wp/v2/media',
        '/wp/v2/categories',
        '/wp/v2/tags',
        '/wp/v2/users',
        '/wp/v2/comments',
    ];
    
    const schemas = {};
    
    for (const endpoint of commonEndpoints) {
        try {
            const response = await fetch(`${REST_API_BASE}${endpoint}`, {
                method: 'OPTIONS',
            });
            
            if (response.ok) {
                const schema = await response.json();
                schemas[endpoint] = schema;
            }
        } catch (error) {
            console.warn(`⚠️  Failed to get schema for ${endpoint}:`, error.message);
        }
    }
    
    return schemas;
}

/**
 * Generate schema documentation
 */
function generateSchemaDocs(schemas) {
    let docs = `# REST API Schemas

This document contains schema information for REST API endpoints.

`;

    Object.keys(schemas).forEach(endpoint => {
        const schema = schemas[endpoint];
        docs += `## ${endpoint}\n\n`;
        
        if (schema.description) {
            docs += `${schema.description}\n\n`;
        }
        
        docs += '```json\n';
        docs += JSON.stringify(schema, null, 2);
        docs += '\n```\n\n';
        docs += '---\n\n';
    });
    
    return docs;
}

/**
 * Main execution function
 */
async function main() {
    console.log('🚀 Starting REST API analysis...');
    
    // Ensure output directory exists
    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }
    
    // Discover endpoints
    const endpoints = await discoverEndpoints();
    
    // Generate endpoint documentation
    const endpointDocs = generateEndpointDocs(endpoints);
    fs.writeFileSync(path.join(OUTPUT_DIR, 'endpoints.md'), endpointDocs);
    
    // Analyze schemas
    const schemas = await analyzeEndpointSchemas();
    const schemaDocs = generateSchemaDocs(schemas);
    fs.writeFileSync(path.join(OUTPUT_DIR, 'schemas.md'), schemaDocs);
    
    console.log('✅ REST API analysis completed!');
    console.log(`📁 Output directory: ${OUTPUT_DIR}`);
    console.log('📄 Generated files:');
    console.log('  - endpoints.md');
    console.log('  - schemas.md');
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

module.exports = {
    discoverEndpoints,
    generateEndpointDocs,
    analyzeEndpointSchemas,
};
```

### 3. Code Example Validation

#### Example Validator

`scripts/validate-examples.js`:

```javascript
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const EXAMPLES_DIR = './docs/api/examples';
const VALIDATION_RESULTS = './docs/api/validation-results.json';

/**
 * Find all code example files
 */
function findExampleFiles(dir = EXAMPLES_DIR) {
    const files = [];
    
    function walkDir(currentDir) {
        const entries = fs.readdirSync(currentDir);
        
        entries.forEach(entry => {
            const fullPath = path.join(currentDir, entry);
            const stat = fs.statSync(fullPath);
            
            if (stat.isDirectory()) {
                walkDir(fullPath);
            } else if (entry.endsWith('.js') || entry.endsWith('.py') || entry.endsWith('.php')) {
                files.push(fullPath);
            }
        });
    }
    
    if (fs.existsSync(dir)) {
        walkDir(dir);
    }
    
    return files;
}

/**
 * Validate JavaScript files
 */
function validateJavaScript(filePath) {
    console.log(`🔍 Validating JavaScript: ${filePath}`);
    
    try {
        // Check syntax
        execSync(`node --check "${filePath}"`, { stdio: 'pipe' });
        
        // Check for common issues
        const content = fs.readFileSync(filePath, 'utf8');
        const issues = [];
        
        // Check for console.log in production examples
        if (content.includes('console.log') && !filePath.includes('debug')) {
            issues.push('Contains console.log statements');
        }
        
        // Check for hardcoded URLs
        if (content.includes('localhost') && !filePath.includes('example')) {
            issues.push('Contains hardcoded localhost URLs');
        }
        
        // Check for missing error handling
        if (content.includes('await ') && !content.includes('try') && !content.includes('catch')) {
            issues.push('Missing error handling for async operations');
        }
        
        return {
            valid: true,
            issues,
        };
    } catch (error) {
        return {
            valid: false,
            error: error.message,
        };
    }
}

/**
 * Validate Python files
 */
function validatePython(filePath) {
    console.log(`🔍 Validating Python: ${filePath}`);
    
    try {
        // Check syntax
        execSync(`python3 -m py_compile "${filePath}"`, { stdio: 'pipe' });
        
        return {
            valid: true,
            issues: [],
        };
    } catch (error) {
        return {
            valid: false,
            error: error.message,
        };
    }
}

/**
 * Validate PHP files
 */
function validatePHP(filePath) {
    console.log(`🔍 Validating PHP: ${filePath}`);
    
    try {
        // Check syntax
        execSync(`php -l "${filePath}"`, { stdio: 'pipe' });
        
        return {
            valid: true,
            issues: [],
        };
    } catch (error) {
        return {
            valid: false,
            error: error.message,
        };
    }
}

/**
 * Validate a single file
 */
function validateFile(filePath) {
    const ext = path.extname(filePath);
    
    switch (ext) {
        case '.js':
            return validateJavaScript(filePath);
        case '.py':
            return validatePython(filePath);
        case '.php':
            return validatePHP(filePath);
        default:
            return {
                valid: true,
                issues: ['Unknown file type, skipping validation'],
            };
    }
}

/**
 * Main validation function
 */
function main() {
    console.log('🚀 Starting code example validation...');
    
    const exampleFiles = findExampleFiles();
    console.log(`📄 Found ${exampleFiles.length} example files`);
    
    const results = {
        timestamp: new Date().toISOString(),
        totalFiles: exampleFiles.length,
        validFiles: 0,
        invalidFiles: 0,
        files: {},
    };
    
    exampleFiles.forEach(filePath => {
        const relativePath = path.relative('.', filePath);
        const validation = validateFile(filePath);
        
        results.files[relativePath] = validation;
        
        if (validation.valid) {
            results.validFiles++;
            console.log(`✅ ${relativePath}`);
        } else {
            results.invalidFiles++;
            console.log(`❌ ${relativePath}: ${validation.error}`);
        }
        
        if (validation.issues && validation.issues.length > 0) {
            console.log(`⚠️  Issues in ${relativePath}:`);
            validation.issues.forEach(issue => {
                console.log(`   - ${issue}`);
            });
        }
    });
    
    // Save results
    fs.writeFileSync(VALIDATION_RESULTS, JSON.stringify(results, null, 2));
    
    console.log('\n📊 Validation Summary:');
    console.log(`   Valid files: ${results.validFiles}`);
    console.log(`   Invalid files: ${results.invalidFiles}`);
    console.log(`   Success rate: ${((results.validFiles / results.totalFiles) * 100).toFixed(1)}%`);
    
    if (results.invalidFiles > 0) {
        console.log('\n❌ Validation failed! Please fix the issues above.');
        process.exit(1);
    } else {
        console.log('\n✅ All examples validated successfully!');
    }
}

// Run if called directly
if (require.main === module) {
    main();
}

module.exports = {
    findExampleFiles,
    validateFile,
};
```

## GitHub Actions Workflows

### Documentation Generation Workflow

`.github/workflows/generate-docs.yml`:

```yaml
name: Generate API Documentation

on:
  push:
    branches: [main, develop]
    paths:
      - 'wordpress/**'
      - 'docs/api/**'
  pull_request:
    branches: [main]
    paths:
      - 'wordpress/**'
      - 'docs/api/**'
  schedule:
    # Run daily at 2 AM UTC
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: root_password
          MYSQL_DATABASE: wordpress
          MYSQL_USER: wordpress
          MYSQL_PASSWORD: wordpress_password
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping -h localhost"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd="redis-cli ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
          extensions: mysqli, pdo_mysql, gd, zip, curl, mbstring, xml, json

      - name: Install Node.js dependencies
        run: npm install

      - name: Install Python dependencies
        run: |
          python -m pip install --upgrade pip
          pip install requests graphql-core

      - name: Start WordPress services
        run: |
          docker-compose up -d wordpress
          # Wait for WordPress to be ready
          timeout 300 bash -c 'until curl -f http://localhost:8080/wp-admin/admin-ajax.php; do sleep 5; done'

      - name: Configure WordPress
        run: |
          # Install and activate required plugins
          docker-compose exec -T wordpress wp plugin install wp-graphql --activate --allow-root
          docker-compose exec -T wordpress wp plugin install wp-graphql-acf --activate --allow-root
          
          # Create test content for documentation
          docker-compose exec -T wordpress wp post create --post_type=post --post_title="Sample Post" --post_content="Sample content" --post_status=publish --allow-root

      - name: Generate GraphQL documentation
        run: |
          node scripts/generate-graphql-docs.js
        env:
          GRAPHQL_ENDPOINT: http://localhost:8080/graphql

      - name: Analyze REST API endpoints
        run: |
          node scripts/analyze-rest-endpoints.js
        env:
          WP_BASE_URL: http://localhost:8080

      - name: Validate code examples
        run: |
          node scripts/validate-examples.js

      - name: Generate API changelog
        run: |
          node scripts/generate-changelog.js

      - name: Check for changes
        id: changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          
          if git diff --quiet; then
            echo "has_changes=false" >> $GITHUB_OUTPUT
          else
            echo "has_changes=true" >> $GITHUB_OUTPUT
          fi

      - name: Commit documentation updates
        if: steps.changes.outputs.has_changes == 'true'
        run: |
          git add docs/
          git commit -m "docs: auto-update API documentation
          
          - Updated GraphQL schema documentation
          - Refreshed REST API endpoint analysis
          - Validated code examples
          - Generated changelog updates
          
          🤖 Generated with [Claude Code](https://claude.ai/code)
          
          Co-Authored-By: GitHub Actions <noreply@github.com>"

      - name: Push changes
        if: steps.changes.outputs.has_changes == 'true' && github.event_name != 'pull_request'
        run: |
          git push origin ${{ github.ref_name }}

      - name: Sync to Confluence
        if: steps.changes.outputs.has_changes == 'true'
        run: |
          node scripts/sync-confluence-enhanced.js
        env:
          CONFLUENCE_URL: ${{ secrets.CONFLUENCE_URL }}
          CONFLUENCE_USERNAME: ${{ secrets.CONFLUENCE_USERNAME }}
          CONFLUENCE_API_TOKEN: ${{ secrets.CONFLUENCE_API_TOKEN }}
          CONFLUENCE_SPACE_KEY: HWPSK

      - name: Create summary
        run: |
          echo "## 📚 Documentation Generation Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **GraphQL Schema**: Updated with latest types and queries" >> $GITHUB_STEP_SUMMARY
          echo "- **REST Endpoints**: Analyzed and documented" >> $GITHUB_STEP_SUMMARY
          echo "- **Code Examples**: Validated for syntax and best practices" >> $GITHUB_STEP_SUMMARY
          
          if [ -f docs/api/validation-results.json ]; then
            VALID_FILES=$(jq '.validFiles' docs/api/validation-results.json)
            TOTAL_FILES=$(jq '.totalFiles' docs/api/validation-results.json)
            echo "- **Validation Results**: $VALID_FILES/$TOTAL_FILES files passed" >> $GITHUB_STEP_SUMMARY
          fi
          
          if [ "${{ steps.changes.outputs.has_changes }}" = "true" ]; then
            echo "- **Status**: ✅ Documentation updated successfully" >> $GITHUB_STEP_SUMMARY
          else
            echo "- **Status**: ℹ️ No changes detected" >> $GITHUB_STEP_SUMMARY
          fi

      - name: Upload documentation artifacts
        uses: actions/upload-artifact@v4
        with:
          name: api-documentation
          path: |
            docs/api/
            !docs/api/.gitkeep
          retention-days: 30

  test-documentation:
    runs-on: ubuntu-latest
    needs: generate-docs
    if: github.event_name == 'pull_request'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Download documentation artifacts
        uses: actions/download-artifact@v4
        with:
          name: api-documentation
          path: docs/api/

      - name: Test documentation links
        run: |
          # Install markdown link checker
          npm install -g markdown-link-check
          
          # Check all markdown files for broken links
          find docs/api -name "*.md" -exec markdown-link-check {} \;

      - name: Validate JSON files
        run: |
          # Validate any JSON files in documentation
          find docs/api -name "*.json" -exec python -m json.tool {} \; > /dev/null

      - name: Check documentation coverage
        run: |
          node scripts/check-doc-coverage.js
```

### Confluence Sync Workflow

`.github/workflows/sync-confluence.yml`:

```yaml
name: Sync Documentation to Confluence

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
  workflow_dispatch:
    inputs:
      space_key:
        description: 'Confluence space key'
        required: true
        default: 'HWPSK'
      force_sync:
        description: 'Force sync all pages'
        type: boolean
        default: false

jobs:
  sync-confluence:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm install

      - name: Sync to Confluence
        run: |
          node scripts/sync-confluence-enhanced.js
        env:
          CONFLUENCE_URL: ${{ secrets.CONFLUENCE_URL }}
          CONFLUENCE_USERNAME: ${{ secrets.CONFLUENCE_USERNAME }}
          CONFLUENCE_API_TOKEN: ${{ secrets.CONFLUENCE_API_TOKEN }}
          CONFLUENCE_SPACE_KEY: ${{ github.event.inputs.space_key || 'HWPSK' }}
          FORCE_SYNC: ${{ github.event.inputs.force_sync || 'false' }}

      - name: Create summary
        run: |
          echo "## 🔄 Confluence Sync Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Space**: ${{ github.event.inputs.space_key || 'HWPSK' }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Force Sync**: ${{ github.event.inputs.force_sync || 'false' }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ✅ Documentation synced successfully" >> $GITHUB_STEP_SUMMARY
```

## Documentation Quality Checks

### Coverage Analysis

`scripts/check-doc-coverage.js`:

```javascript
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Configuration
const DOCS_DIR = './docs';
const REQUIRED_SECTIONS = [
    'api/README.md',
    'api/graphql/README.md',
    'api/rest/README.md',
    'api/authentication/README.md',
    'api/versioning/README.md',
    'api/examples/javascript/',
    'api/integration/nextjs.md',
];

/**
 * Check documentation coverage
 */
function checkCoverage() {
    console.log('📊 Checking documentation coverage...');
    
    const results = {
        total: REQUIRED_SECTIONS.length,
        present: 0,
        missing: [],
        issues: [],
    };
    
    REQUIRED_SECTIONS.forEach(section => {
        const fullPath = path.join(DOCS_DIR, section);
        
        if (fs.existsSync(fullPath)) {
            results.present++;
            
            // Check if it's a directory that should have content
            if (section.endsWith('/')) {
                const files = fs.readdirSync(fullPath);
                if (files.length === 0) {
                    results.issues.push(`${section} directory is empty`);
                }
            } else {
                // Check file size for markdown files
                const stats = fs.statSync(fullPath);
                if (stats.size < 100) {
                    results.issues.push(`${section} is too small (${stats.size} bytes)`);
                }
            }
        } else {
            results.missing.push(section);
        }
    });
    
    return results;
}

/**
 * Main function
 */
function main() {
    const coverage = checkCoverage();
    
    console.log('\n📋 Documentation Coverage Report:');
    console.log(`   Present: ${coverage.present}/${coverage.total} sections`);
    console.log(`   Coverage: ${((coverage.present / coverage.total) * 100).toFixed(1)}%`);
    
    if (coverage.missing.length > 0) {
        console.log('\n❌ Missing sections:');
        coverage.missing.forEach(section => {
            console.log(`   - ${section}`);
        });
    }
    
    if (coverage.issues.length > 0) {
        console.log('\n⚠️  Issues found:');
        coverage.issues.forEach(issue => {
            console.log(`   - ${issue}`);
        });
    }
    
    if (coverage.missing.length === 0 && coverage.issues.length === 0) {
        console.log('\n✅ Documentation coverage is complete!');
    } else {
        console.log('\n❌ Documentation coverage needs improvement.');
        process.exit(1);
    }
}

// Run if called directly
if (require.main === module) {
    main();
}

module.exports = { checkCoverage };
```

## Monitoring & Alerts

### Documentation Health Dashboard

`scripts/generate-health-dashboard.js`:

```javascript
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Generate documentation health dashboard
 */
function generateHealthDashboard() {
    const healthData = {
        timestamp: new Date().toISOString(),
        metrics: {
            totalFiles: 0,
            totalSize: 0,
            lastUpdated: null,
            brokenLinks: 0,
            validationErrors: 0,
        },
        status: 'healthy',
    };
    
    // Scan documentation directory
    function scanDirectory(dir) {
        const entries = fs.readdirSync(dir);
        
        entries.forEach(entry => {
            const fullPath = path.join(dir, entry);
            const stat = fs.statSync(fullPath);
            
            if (stat.isDirectory()) {
                scanDirectory(fullPath);
            } else if (entry.endsWith('.md')) {
                healthData.metrics.totalFiles++;
                healthData.metrics.totalSize += stat.size;
                
                if (!healthData.metrics.lastUpdated || stat.mtime > new Date(healthData.metrics.lastUpdated)) {
                    healthData.metrics.lastUpdated = stat.mtime.toISOString();
                }
            }
        });
    }
    
    scanDirectory('./docs');
    
    // Load validation results if available
    const validationFile = './docs/api/validation-results.json';
    if (fs.existsSync(validationFile)) {
        const validation = JSON.parse(fs.readFileSync(validationFile));
        healthData.metrics.validationErrors = validation.invalidFiles;
    }
    
    // Determine overall status
    if (healthData.metrics.validationErrors > 0) {
        healthData.status = 'warning';
    }
    
    // Generate HTML dashboard
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API Documentation Health Dashboard</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
        .metric { background: #f8f9fa; padding: 20px; margin: 10px 0; border-radius: 8px; }
        .status-healthy { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-error { color: #dc3545; }
    </style>
</head>
<body>
    <h1>📚 API Documentation Health Dashboard</h1>
    
    <div class="metric">
        <h2>Overall Status: <span class="status-${healthData.status}">${healthData.status.toUpperCase()}</span></h2>
        <p>Last updated: ${healthData.timestamp}</p>
    </div>
    
    <div class="metric">
        <h3>📄 Documentation Files</h3>
        <p>Total files: ${healthData.metrics.totalFiles}</p>
        <p>Total size: ${(healthData.metrics.totalSize / 1024).toFixed(1)} KB</p>
        <p>Last modified: ${healthData.metrics.lastUpdated || 'Unknown'}</p>
    </div>
    
    <div class="metric">
        <h3>✅ Validation Status</h3>
        <p>Validation errors: ${healthData.metrics.validationErrors}</p>
        <p>Broken links: ${healthData.metrics.brokenLinks}</p>
    </div>
    
    <div class="metric">
        <h3>🔗 Quick Links</h3>
        <ul>
            <li><a href="./api/README.md">API Documentation</a></li>
            <li><a href="./api/graphql/README.md">GraphQL API</a></li>
            <li><a href="./api/rest/README.md">REST API</a></li>
            <li><a href="./api/authentication/README.md">Authentication</a></li>
        </ul>
    </div>
</body>
</html>
    `;
    
    fs.writeFileSync('./docs/health-dashboard.html', html);
    fs.writeFileSync('./docs/health-data.json', JSON.stringify(healthData, null, 2));
    
    console.log('✅ Health dashboard generated successfully!');
    console.log(`📊 Status: ${healthData.status}`);
    console.log(`📄 Files: ${healthData.metrics.totalFiles}`);
}

// Run if called directly
if (require.main === module) {
    generateHealthDashboard();
}

module.exports = { generateHealthDashboard };
```

## Usage

### Manual Generation

```bash
# Generate all documentation
npm run docs:generate

# Generate specific components
npm run docs:graphql
npm run docs:rest
npm run docs:validate

# Sync to Confluence
npm run docs:sync

# Generate health dashboard
npm run docs:health
```

### Package.json Scripts

```json
{
  "scripts": {
    "docs:generate": "node scripts/generate-graphql-docs.js && node scripts/analyze-rest-endpoints.js",
    "docs:graphql": "node scripts/generate-graphql-docs.js",
    "docs:rest": "node scripts/analyze-rest-endpoints.js", 
    "docs:validate": "node scripts/validate-examples.js",
    "docs:sync": "node scripts/sync-confluence-enhanced.js",
    "docs:health": "node scripts/generate-health-dashboard.js",
    "docs:coverage": "node scripts/check-doc-coverage.js"
  }
}
```

This automation system ensures our API documentation stays current, accurate, and useful for developers while minimizing manual maintenance overhead.
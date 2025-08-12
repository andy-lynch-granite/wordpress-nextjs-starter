# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a headless WordPress + Next.js starter kit designed for production deployment on Azure. The project consists of:

- **Backend**: Headless WordPress with GraphQL API
- **Frontend**: Next.js 14+ with App Router (Full SSG)  
- **Infrastructure**: Azure-based deployment with multi-environment support
- **CI/CD**: GitHub Actions workflows

## Architecture

The project follows a headless CMS architecture where WordPress serves as the content management backend via GraphQL, while Next.js handles the frontend presentation layer with full static site generation.

### Key Components

- `frontend/` - Next.js application with App Router
- `wordpress/` - WordPress themes and plugins for headless operation
- `infrastructure/` - Azure deployment configurations (Bicep/Terraform/Docker)
- `.github/workflows/` - CI/CD pipelines for multi-environment deployment
- `tests/` - Comprehensive test suite (unit, integration, e2e)

## Development Commands

### Local Development
```bash
# Start local development environment
docker-compose up

# Access points:
# WordPress admin: http://localhost:8080/wp-admin  
# Next.js frontend: http://localhost:3000
```

## Claude Code Configuration

This project includes advanced Claude Code configuration:

### Specialized Agents
- **architect**: System design, infrastructure planning, documentation
- **developer**: Frontend/backend development and implementation  
- **devops**: CI/CD, infrastructure, and deployment tasks
- **tester**: Quality assurance and testing strategy

### Context Namespaces
- **architecture**: High-level system design and infrastructure
- **frontend**: Next.js development and configuration
- **backend**: WordPress backend and API development
- **infrastructure**: Deployment and infrastructure management
- **testing**: Test implementation and quality assurance

### MCP Integration
- Confluence integration for documentation
- GitHub integration for repository management
- Filesystem access for local development

## Project Structure Context

The project uses a monorepo structure with clear separation of concerns:
- Frontend and backend are decoupled via GraphQL
- Infrastructure as code with multiple deployment options
- Comprehensive testing strategy across all layers
- Multi-environment CI/CD with Azure deployment
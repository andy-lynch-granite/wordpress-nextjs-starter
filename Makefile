.PHONY: help install start stop restart logs status clean build rebuild test shell wp-shell db-shell redis-shell backup restore

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Environment setup
install: ## Install and setup the development environment
	@echo "Setting up headless WordPress + Next.js development environment..."
	@mkdir -p logs/wordpress logs/frontend logs/mysql logs/redis
	@mkdir -p wordpress/themes/custom wordpress/plugins/custom wordpress/uploads
	@chmod 755 logs wordpress/uploads
	@echo "✅ Directories created"
	@docker-compose build
	@echo "✅ Docker images built"
	@echo "\n🚀 Run 'make start' to start the development environment"

# Container management
start: ## Start all services
	@echo "Starting headless WordPress + Next.js development environment..."
	@docker-compose up -d
	@echo "\n⏳ Waiting for services to be ready..."
	@sleep 10
	@$(MAKE) status
	@echo "\n🌐 Access URLs:"
	@echo "   WordPress Admin: http://localhost:8080/wp-admin (admin/admin_password)"
	@echo "   GraphQL Endpoint: http://localhost:8080/graphql"
	@echo "   Next.js Frontend: http://localhost:3000"
	@echo "   phpMyAdmin: http://localhost:8081"
	@echo "   Redis Commander: http://localhost:8082"
	@echo "   Mailhog: http://localhost:8025"

start-dev: ## Start services with development tools
	@echo "Starting with development tools..."
	@docker-compose --profile dev up -d
	@$(MAKE) status

stop: ## Stop all services
	@echo "Stopping all services..."
	@docker-compose down
	@echo "✅ All services stopped"

restart: ## Restart all services
	@echo "Restarting all services..."
	@docker-compose restart
	@$(MAKE) status

# Logs and debugging
logs: ## Show logs for all services
	@docker-compose logs -f

logs-wp: ## Show WordPress logs
	@docker-compose logs -f wordpress

logs-fe: ## Show frontend logs
	@docker-compose logs -f frontend

logs-db: ## Show MySQL logs
	@docker-compose logs -f mysql

logs-redis: ## Show Redis logs
	@docker-compose logs -f redis

status: ## Show status of all services
	@echo "📊 Service Status:"
	@docker-compose ps
	@echo "\n🔍 Health Checks:"
	@docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Shell access
shell: ## Access the devtools container shell
	@docker-compose run --rm devtools /bin/bash

wp-shell: ## Access WordPress container shell
	@docker-compose exec wordpress /bin/bash

fe-shell: ## Access frontend container shell
	@docker-compose exec frontend /bin/sh

db-shell: ## Access MySQL shell
	@docker-compose exec mysql mysql -u root -proot_password wordpress

redis-shell: ## Access Redis CLI
	@docker-compose exec redis redis-cli -a redis_password

# Build and rebuild
build: ## Build all Docker images
	@echo "Building Docker images..."
	@docker-compose build --no-cache
	@echo "✅ Images built successfully"

rebuild: ## Rebuild and restart services
	@echo "Rebuilding and restarting services..."
	@docker-compose down
	@docker-compose build --no-cache
	@docker-compose up -d
	@$(MAKE) status

# Data management
backup: ## Create backup of database and uploads
	@echo "Creating backup..."
	@mkdir -p backups
	@docker-compose exec mysql mysqldump -u root -proot_password wordpress > backups/wordpress_$(shell date +%Y%m%d_%H%M%S).sql
	@tar -czf backups/uploads_$(shell date +%Y%m%d_%H%M%S).tar.gz wordpress/uploads/
	@echo "✅ Backup created in backups/ directory"

restore: ## Restore from latest backup (use BACKUP_FILE=filename to specify)
	@echo "Restoring from backup..."
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "Please specify BACKUP_FILE=filename.sql"; \
		exit 1; \
	fi
	@docker-compose exec -T mysql mysql -u root -proot_password wordpress < backups/$(BACKUP_FILE)
	@echo "✅ Database restored from $(BACKUP_FILE)"

# Testing and validation
test: ## Run basic health checks
	@echo "Running health checks..."
	@echo "\n1. WordPress health check:"
	@curl -f http://localhost:8080/wp-admin/admin-ajax.php || echo "❌ WordPress not responding"
	@echo "\n2. GraphQL endpoint check:"
	@curl -f -X POST http://localhost:8080/graphql -H "Content-Type: application/json" -d '{"query":"{posts{nodes{title}}}"}'| jq '.data.posts.nodes | length' || echo "❌ GraphQL not responding"
	@echo "\n3. Frontend health check:"
	@curl -f http://localhost:3000/api/health || echo "❌ Frontend not responding"
	@echo "\n✅ Health checks completed"

test-graphql: ## Test GraphQL queries
	@echo "Testing GraphQL queries..."
	@echo "\n📝 Getting posts:"
	@curl -s -X POST http://localhost:8080/graphql \
		-H "Content-Type: application/json" \
		-d '{"query":"query GetPosts { posts { nodes { title slug date } } }"}' | jq '.'

# Cleanup
clean: ## Stop services and remove containers, networks, and volumes
	@echo "⚠️  This will remove all containers, networks, and volumes!"
	@echo "Press Ctrl+C to cancel, or press Enter to continue..."
	@read
	@docker-compose down -v --rmi all --remove-orphans
	@docker system prune -f
	@echo "✅ Cleanup completed"

clean-soft: ## Stop services and remove containers (keep volumes)
	@echo "Removing containers and networks (keeping volumes)..."
	@docker-compose down --remove-orphans
	@echo "✅ Soft cleanup completed"

# Development helpers
wp-install: ## Install WordPress plugins via WP-CLI
	@echo "Installing additional WordPress plugins..."
	@docker-compose exec wordpress wp plugin install $(PLUGIN) --activate --allow-root

wp-reset: ## Reset WordPress (removes all content)
	@echo "⚠️  This will reset WordPress and remove all content!"
	@echo "Press Ctrl+C to cancel, or press Enter to continue..."
	@read
	@docker-compose exec wordpress wp db reset --yes --allow-root
	@docker-compose restart wordpress
	@echo "✅ WordPress reset completed"

fe-install: ## Install frontend dependencies
	@echo "Installing frontend dependencies..."
	@docker-compose exec frontend npm install

fe-build: ## Build frontend for production
	@echo "Building frontend..."
	@docker-compose exec frontend npm run build

fe-analyze: ## Analyze frontend bundle
	@echo "Analyzing frontend bundle..."
	@docker-compose exec frontend npm run analyze

# Monitoring
monitor: ## Show real-time resource usage
	@watch -n 2 'docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"'

info: ## Show environment information
	@echo "🔧 Environment Information:"
	@echo "Docker Compose version: $$(docker-compose --version)"
	@echo "Docker version: $$(docker --version)"
	@echo "\n📦 Container Status:"
	@docker-compose ps
	@echo "\n💾 Volume Usage:"
	@docker volume ls --filter name=wordpess-claude
	@echo "\n🌐 Network Info:"
	@docker network ls --filter name=wordpess-claude
	@echo "\n📊 Resource Usage:"
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Quick actions
quick-start: install start ## Quick setup and start (alias for install + start)

dev: ## Start development environment with all tools
	@$(MAKE) start-dev
	@echo "\n🛠️  Development environment ready!"
	@echo "Run 'make shell' to access development tools"

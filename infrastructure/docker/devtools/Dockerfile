FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    jq \
    mysql-client \
    redis-tools \
    zip \
    unzip \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install PHP 8.2 and WP-CLI
RUN apt-get update && apt-get install -y \
    php8.1 \
    php8.1-cli \
    php8.1-mysql \
    php8.1-redis \
    php8.1-curl \
    php8.1-xml \
    php8.1-mbstring \
    php8.1-zip \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/main/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli && rm -rf /var/lib/apt/lists/*

# Install development tools
RUN npm install -g \
    @graphql-codegen/cli \
    graphql-playground-cli \
    pm2 \
    nodemon

# Create workspace directory
WORKDIR /workspace

# Set up aliases and shortcuts
RUN echo 'alias ll="ls -alF"' >> ~/.bashrc && \
    echo 'alias la="ls -A"' >> ~/.bashrc && \
    echo 'alias l="ls -CF"' >> ~/.bashrc && \
    echo 'alias wp-logs="docker-compose logs -f wordpress"' >> ~/.bashrc && \
    echo 'alias fe-logs="docker-compose logs -f frontend"' >> ~/.bashrc && \
    echo 'alias db-connect="mysql -h mysql -u root -p"' >> ~/.bashrc && \
    echo 'alias redis-connect="redis-cli -h redis -a redis_password"' >> ~/.bashrc

# Copy utility scripts
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Set default command
CMD ["/bin/bash"]

FROM wordpress:6.4-php8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    vim \
    less \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install opcache

# Install Redis PHP extension
RUN pecl install redis && docker-php-ext-enable redis

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/main/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp && \
    wp --info --allow-root

# Create necessary directories
RUN mkdir -p /var/log/wordpress && \
    chown www-data:www-data /var/log/wordpress

# Copy configuration files
COPY php.ini /usr/local/etc/php/conf.d/custom.ini
COPY wp-config-local.php /var/www/html/wp-config-local.php

# Copy setup scripts
COPY wp-setup.sh /usr/local/bin/wp-setup.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint-custom.sh
RUN chmod +x /usr/local/bin/wp-setup.sh && \
    chmod +x /usr/local/bin/docker-entrypoint-custom.sh

# Set up Apache configuration for development
RUN a2enmod rewrite && \
    a2enmod headers && \
    a2enmod expires

# Copy Apache virtual host configuration
COPY apache-vhost.conf /etc/apache2/sites-available/000-default.conf

# Create uploads directory with proper permissions
RUN mkdir -p /var/www/html/wp-content/uploads && \
    chown -R www-data:www-data /var/www/html/wp-content/uploads

# Set working directory
WORKDIR /var/www/html

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-custom.sh"]
CMD ["apache2-foreground"]

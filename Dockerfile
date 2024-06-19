# Stage 1: Build
FROM node:20 as builder

WORKDIR /app
COPY . .
RUN yarn install && yarn build

# Stage 2: Production
FROM wordpress:php8.3-fpm

WORKDIR /var/www/html

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    libzip-dev \
    zip \
    jpegoptim optipng pngquant gifsicle \
    vim \
    unzip \
    git \
    curl \
    gnupg2 \
    lsb-release

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install extensions
RUN docker-php-ext-install pdo_mysql zip exif pcntl
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install -j$(nproc) gd

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install Node.js using NodeSource PPA
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN echo "deb https://deb.nodesource.com/node_20.x $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update && apt-get install -y nodejs

# Install yarn using the Debian package repository
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn

# Copy build artifacts from the builder stage
COPY --from=builder /app/build /var/www/html

# Add user for application
RUN groupadd -g 1000 www
RUN useradd -u 1000 -ms /bin/bash -g www www

# Change ownership of the work directory
RUN chown -R www:www /var/www/html

USER www

EXPOSE 9000
CMD ["php-fpm"]

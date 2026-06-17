# syntax=docker/dockerfile:1
#
# One-image build for the HR Tool. No Node needed: the compiled Vue/Inertia
# assets in public/build/ are committed to the repo, so there is no npm step.
#
FROM php:8.2-cli-bookworm

# System libraries for the PHP extensions this app actually uses.
#   libpq-dev   -> pdo_pgsql / pgsql  (PostgreSQL is the ONLY DB the app runs on
#                  unchanged: it uses ILIKE + a raw CHECK constraint)
#   libonig-dev -> mbstring
# The app needs NO image processing (no GD/Imagick), NO intl, NO zip/gmp.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev \
        libonig-dev \
        unzip \
    && docker-php-ext-install -j"$(nproc)" pdo_pgsql pgsql mbstring \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# ctype, fileinfo, filter, hash, openssl, tokenizer, curl, json, pdo, dom, xml
# are compiled into the official php:8.2 image by default — nothing to add.

# Composer (from the official Composer image)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Install PHP deps first (better layer caching).
COPY composer.json composer.lock ./
# IMPORTANT: install WITH dev dependencies. StarterSeeder builds the admin via
# Employee::factory()/Branch::factory(), which call fake(); fakerphp/faker is
# a DEV dependency. A --no-dev build would fatal the seeder and leave the app
# with NO login user.
RUN composer install --no-interaction --no-progress --optimize-autoloader --no-scripts

# Copy the rest of the app (includes the committed public/build — no npm).
COPY . .

# Finish autoload + package discovery now that all source is present.
RUN composer dump-autoload --optimize \
    && php artisan package:discover --ansi || true

# Normalize line endings + make the entrypoint executable, so that even if the
# project was downloaded as a ZIP on Windows (CRLF) the script still runs.
RUN sed -i 's/\r$//' docker/entrypoint.sh && chmod +x docker/entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["docker/entrypoint.sh"]

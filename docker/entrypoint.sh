#!/usr/bin/env bash
# First-boot bootstrap for the HR Tool container: wait for Postgres, create the
# app key, run migrations, seed the starter data once, then serve.
set -e

DB_DSN="pgsql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_DATABASE}"

echo "==> Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT} ..."
# php:8.2-cli has no pg_isready binary, so probe with PDO (pdo_pgsql is built in).
until php -r '
    try {
        new PDO("'"$DB_DSN"'", getenv("DB_USERNAME"), getenv("DB_PASSWORD"));
        exit(0);
    } catch (Throwable $e) { exit(1); }
'; do
    sleep 2
    echo "    ...still waiting for the database"
done
echo "==> Database is up."

# Give key:generate a .env file to write to (first boot only).
if [ ! -f .env ]; then
    cp docker/app.env .env
fi

# Generate APP_KEY only if one isn't already set (fixes the
# "No application encryption key has been specified" error).
if ! grep -q '^APP_KEY=base64:' .env; then
    echo "==> Generating application key..."
    php artisan key:generate --force
fi

echo "==> Running migrations..."
php artisan migrate --force

# Seed ONLY on first boot. StarterSeeder is not idempotent (it would crash on
# the roles' unique constraint if run twice), so gate it on an empty database.
SEEDED="$(php -r '
    try {
        $p = new PDO("'"$DB_DSN"'", getenv("DB_USERNAME"), getenv("DB_PASSWORD"));
        echo (int) $p->query("SELECT count(*) FROM globals")->fetchColumn();
    } catch (Throwable $e) { echo 0; }
')"
if [ "${SEEDED:-0}" = "0" ]; then
    echo "==> Seeding starter data (first boot)..."
    php artisan db:seed --seeder=StarterSeeder --force
else
    echo "==> Data already present — skipping seed."
fi

chmod -R ug+rw storage bootstrap/cache 2>/dev/null || true

echo ""
echo "=================================================================="
echo "  HR TOOL IS READY  ->  http://localhost:8000"
echo "  Log in with:   super@root.com   /   password"
echo "  Sent emails:   http://localhost:8025   (Mailpit inbox)"
echo "=================================================================="
echo ""

# --host=0.0.0.0 is mandatory so the port is reachable from the host machine.
exec php artisan serve --host=0.0.0.0 --port=8000

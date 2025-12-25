#!/bin/bash
echo "  [DEBUG] myapp/03-seed-data.sh starting..."
# Seed database with development data for this specific repo
#
# Runs after migrations to add test users, sample content, etc.
# Uses a custom seeder class for development data.

if [[ ! -f "${WT_PATH}/artisan" ]]; then
  exit 0
fi

cd "$WT_PATH" || exit 0

echo "  Seeding development data..."
if php artisan db:seed --class=DevDataSeeder --force --quiet 2>/dev/null; then
  echo "  Development data seeded"
else
  # Seeder might not exist, which is fine
  echo "  DevDataSeeder not found or failed - skipping"
fi

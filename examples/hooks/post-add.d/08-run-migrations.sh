#!/bin/bash
echo "  [DEBUG] 08-run-migrations.sh starting..."
# Run Laravel database migrations
#
# Only runs for Laravel projects (artisan file exists).
# Skip by setting: WT_SKIP_MIGRATE=true

if [[ "${WT_SKIP_MIGRATE:-}" == "true" ]]; then
  echo "  Skipping migrations (WT_SKIP_MIGRATE=true)"
  exit 0
fi

if [[ ! -f "${WT_PATH}/artisan" ]]; then
  exit 0
fi

cd "$WT_PATH" || exit 0

echo "  Running migrations..."
if php artisan migrate --force --quiet 2>/dev/null; then
  echo "  Migrations complete"
else
  echo "  Migrations failed - run manually: php artisan migrate"
fi

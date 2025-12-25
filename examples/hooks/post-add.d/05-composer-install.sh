#!/bin/bash
echo "  [DEBUG] 05-composer-install.sh starting..."
# Run composer install for PHP/Laravel projects
#
# Only runs if composer.json exists.
# Skip by setting: WT_SKIP_COMPOSER=true

if [[ "${WT_SKIP_COMPOSER:-}" == "true" ]]; then
  echo "  Skipping composer install (WT_SKIP_COMPOSER=true)"
  exit 0
fi

if [[ ! -f "${WT_PATH}/composer.json" ]]; then
  exit 0
fi

if ! command -v composer >/dev/null 2>&1; then
  echo "  Composer not found - run manually: composer install"
  exit 0
fi

cd "$WT_PATH" || exit 0

echo "  Running composer install..."
if composer install --quiet --ignore-platform-req=ext-imagick 2>/dev/null; then
  echo "  Composer install complete"
else
  echo "  Composer install failed - run manually: composer install"
fi

# Generate app key for Laravel
if [[ -f "artisan" ]]; then
  if php artisan key:generate --force >/dev/null 2>&1; then
    echo "  Generated Laravel app key"
  fi
fi

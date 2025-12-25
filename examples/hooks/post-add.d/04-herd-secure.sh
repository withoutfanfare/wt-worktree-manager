#!/bin/bash
echo "  [DEBUG] 04-herd-secure.sh starting..."
# Secure site with Laravel Herd HTTPS
#
# Creates an SSL certificate for the local development site.
# Skip by setting: WT_SKIP_HERD=true

if [[ "${WT_SKIP_HERD:-}" == "true" ]]; then
  echo "  Skipping Herd secure (WT_SKIP_HERD=true)"
  exit 0
fi

if ! command -v herd >/dev/null 2>&1; then
  echo "  Herd not found - skipping site securing"
  exit 0
fi

# Get site name from path (last component)
site_name="${WT_PATH##*/}"

if herd secure "$site_name" >/dev/null 2>&1; then
  echo "  Secured site: ${site_name}"
else
  echo "  Could not secure site - run: herd secure ${site_name}"
fi

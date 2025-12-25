#!/bin/bash
echo "  [DEBUG] post-rm.d/01-herd-unsecure.sh starting..."
# Unsecure site and clean up Herd configuration
#
# Removes the SSL certificate and nginx config for the site.

if ! command -v herd >/dev/null 2>&1; then
  exit 0
fi

# Get site name from path (last component)
site_name="${WT_PATH##*/}"

# Unsecure the site
herd unsecure "$site_name" >/dev/null 2>&1 || true

# Clean up Herd nginx configs and certificates
# This prevents nginx from failing due to stale configs
HERD_CONFIG="${HOME}/Library/Application Support/Herd"
site_domain="${site_name}.test"

# Remove nginx config
nginx_config="$HERD_CONFIG/config/valet/Nginx/$site_domain"
[[ -f "$nginx_config" ]] && rm -f "$nginx_config" 2>/dev/null

# Remove certificate files
cert_dir="$HERD_CONFIG/config/valet/Certificates"
for ext in crt key csr conf; do
  [[ -f "$cert_dir/${site_domain}.${ext}" ]] && rm -f "$cert_dir/${site_domain}.${ext}" 2>/dev/null
done

echo "  Cleaned up Herd config for ${site_name}"

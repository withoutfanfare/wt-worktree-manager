#!/bin/bash
echo "  [DEBUG] 03-create-database.sh starting..."
# Create MySQL database for the worktree
#
# Uses the same database connection settings as wt:
#   DB_HOST, DB_USER, DB_PASSWORD (from ~/.wtrc or environment)
#
# Skip by setting: WT_SKIP_DB=true

if [[ "${WT_SKIP_DB:-}" == "true" ]]; then
  echo "  Skipping database creation (WT_SKIP_DB=true)"
  exit 0
fi

# Load wt config for database settings
if [[ -f "$HOME/.wtrc" ]]; then
  DB_HOST="${DB_HOST:-$(grep '^DB_HOST=' "$HOME/.wtrc" 2>/dev/null | cut -d= -f2-)}"
  DB_USER="${DB_USER:-$(grep '^DB_USER=' "$HOME/.wtrc" 2>/dev/null | cut -d= -f2-)}"
  DB_PASSWORD="${DB_PASSWORD:-$(grep '^DB_PASSWORD=' "$HOME/.wtrc" 2>/dev/null | cut -d= -f2-)}"
fi

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"

if ! command -v mysql >/dev/null 2>&1; then
  echo "  MySQL client not found - skipping database creation"
  echo "  Run manually: CREATE DATABASE \`${WT_DB_NAME}\`;"
  exit 0
fi

# Build mysql command
mysql_cmd=(mysql -h "$DB_HOST" -u "$DB_USER")
[[ -n "$DB_PASSWORD" ]] && mysql_cmd+=(-p"$DB_PASSWORD")

# Check if database already exists
if "${mysql_cmd[@]}" -e "USE \`${WT_DB_NAME}\`;" 2>/dev/null; then
  echo "  Database already exists: ${WT_DB_NAME}"
  exit 0
fi

# Create database
if "${mysql_cmd[@]}" -e "CREATE DATABASE IF NOT EXISTS \`${WT_DB_NAME}\`;" 2>/dev/null; then
  echo "  Created database: ${WT_DB_NAME}"
else
  echo "  Could not create database - check MySQL connection"
  echo "  Run manually: CREATE DATABASE \`${WT_DB_NAME}\`;"
fi

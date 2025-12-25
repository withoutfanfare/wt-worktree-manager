#!/bin/bash
echo "  [DEBUG] myapp/02-import-database.sh starting..."
# Import database from a pre-configured SQL dump for this repo
#
# Looks for a gzipped SQL file at:
#   ~/Code/Worktree/{repo}/{repo}-db/{repo}.sql.gz
#
# This is useful for repos that need a baseline database with:
#   - Reference data
#   - Test users
#   - Sample content
#
# The import runs AFTER the database is created by the global hook.

# Define the source path
DB_DUMP="$HOME/Code/Worktree/${WT_REPO}/${WT_REPO}-db/${WT_REPO}.sql.gz"

if [[ ! -f "$DB_DUMP" ]]; then
  echo "  No database dump found at $DB_DUMP"
  echo "  Skipping import - database will be empty"
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
  echo "  MySQL client not found - cannot import database"
  exit 0
fi

# Build mysql command
mysql_cmd=(mysql -h "$DB_HOST" -u "$DB_USER")
[[ -n "$DB_PASSWORD" ]] && mysql_cmd+=(-p"$DB_PASSWORD")

echo "  Importing database from $DB_DUMP..."

# Decompress and import
if gunzip -c "$DB_DUMP" | "${mysql_cmd[@]}" "$WT_DB_NAME" 2>/dev/null; then
  echo "  Database imported successfully"
else
  echo "  Database import failed"
  echo "  Try manually: gunzip -c $DB_DUMP | mysql $WT_DB_NAME"
fi

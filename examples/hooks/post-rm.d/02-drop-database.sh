#!/bin/bash
echo "  [DEBUG] post-rm.d/02-drop-database.sh starting..."
# Drop database after worktree removal
#
# Only runs if: WT_DROP_DB=true (set by --drop-db flag)
# This is an opt-in operation - databases are kept by default.

if [[ "${WT_DROP_DB:-}" != "true" ]]; then
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
  echo "  MySQL client not found - cannot drop database"
  exit 0
fi

# Build mysql command
mysql_cmd=(mysql -h "$DB_HOST" -u "$DB_USER")
[[ -n "$DB_PASSWORD" ]] && mysql_cmd+=(-p"$DB_PASSWORD")

# Check if database exists
if ! "${mysql_cmd[@]}" -e "USE \`${WT_DB_NAME}\`;" 2>/dev/null; then
  echo "  Database ${WT_DB_NAME} does not exist"
  exit 0
fi

echo "  Dropping database ${WT_DB_NAME}..."
if "${mysql_cmd[@]}" -e "DROP DATABASE \`${WT_DB_NAME}\`;" 2>/dev/null; then
  echo "  Database dropped: ${WT_DB_NAME}"
else
  echo "  Could not drop database"
fi

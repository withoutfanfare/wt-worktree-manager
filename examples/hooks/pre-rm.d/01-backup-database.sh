#!/bin/bash
echo "  [DEBUG] pre-rm.d/01-backup-database.sh starting..."
# Backup database before worktree removal
#
# Creates a timestamped SQL backup in the configured backup directory.
# Skip by setting: WT_NO_BACKUP=true or passing --no-backup to wt rm
#
# Uses database connection settings from ~/.wtrc:
#   DB_HOST, DB_USER, DB_PASSWORD, DB_BACKUP_DIR

if [[ "${WT_NO_BACKUP:-}" == "true" ]]; then
  echo "  Skipping database backup (--no-backup)"
  exit 0
fi

# Load wt config for database settings
if [[ -f "$HOME/.wtrc" ]]; then
  DB_HOST="${DB_HOST:-$(grep '^DB_HOST=' "$HOME/.wtrc" 2>/dev/null | cut -d= -f2-)}"
  DB_USER="${DB_USER:-$(grep '^DB_USER=' "$HOME/.wtrc" 2>/dev/null | cut -d= -f2-)}"
  DB_PASSWORD="${DB_PASSWORD:-$(grep '^DB_PASSWORD=' "$HOME/.wtrc" 2>/dev/null | cut -d= -f2-)}"
  DB_BACKUP_DIR="${DB_BACKUP_DIR:-$(grep '^DB_BACKUP_DIR=' "$HOME/.wtrc" 2>/dev/null | cut -d= -f2- | sed 's/\$HOME/'"$HOME"'/g' | tr -d '"')}"
fi

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_BACKUP_DIR="${DB_BACKUP_DIR:-$HOME/Code/Project Support/Worktree/Database/Backup}"

if ! command -v mysqldump >/dev/null 2>&1; then
  echo "  mysqldump not found - skipping backup"
  exit 0
fi

# Build mysql command to check if database exists
mysql_cmd=(mysql -h "$DB_HOST" -u "$DB_USER")
[[ -n "$DB_PASSWORD" ]] && mysql_cmd+=(-p"$DB_PASSWORD")

# Check if database exists
if ! "${mysql_cmd[@]}" -e "USE \`${WT_DB_NAME}\`;" 2>/dev/null; then
  echo "  Database ${WT_DB_NAME} does not exist - skipping backup"
  exit 0
fi

# Create backup directory
backup_dir="$DB_BACKUP_DIR/$WT_REPO"
mkdir -p "$backup_dir" || { echo "  Could not create backup directory"; exit 0; }

# Generate backup filename with timestamp
timestamp="$(date +%Y%m%d_%H%M%S)"
backup_file="$backup_dir/${WT_DB_NAME}_${timestamp}.sql"

# Build mysqldump command
mysqldump_cmd=(mysqldump -h "$DB_HOST" -u "$DB_USER")
[[ -n "$DB_PASSWORD" ]] && mysqldump_cmd+=(-p"$DB_PASSWORD")

echo "  Backing up database ${WT_DB_NAME}..."
if "${mysqldump_cmd[@]}" "$WT_DB_NAME" > "$backup_file" 2>/dev/null; then
  echo "  Backup saved: $backup_file"
else
  echo "  Backup failed - continuing anyway"
  rm -f "$backup_file" 2>/dev/null
fi

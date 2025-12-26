#!/usr/bin/env zsh
set -euo pipefail

readonly VERSION="4.0.0"

# Defaults (can be overridden by config file or env vars)
HERD_ROOT="${HERD_ROOT:-$HOME/Herd}"
HERD_CONFIG="${HERD_CONFIG:-$HOME/Library/Application Support/Herd/config}"
DEFAULT_BASE="${WT_BASE_DEFAULT:-origin/staging}"
DEFAULT_EDITOR="${WT_EDITOR:-cursor}"

# URL generation defaults
WT_URL_SUBDOMAIN="${WT_URL_SUBDOMAIN:-}"  # Optional subdomain prefix (e.g., "api" -> api.feature-name.test)

# Database defaults
DB_HOST="${WT_DB_HOST:-127.0.0.1}"
DB_USER="${WT_DB_USER:-root}"
DB_PASSWORD="${WT_DB_PASSWORD:-}"
DB_CREATE="${WT_DB_CREATE:-true}"
DB_BACKUP_DIR="${WT_DB_BACKUP_DIR:-$HOME/Code/Project Support/Worktree/Database/Backup}"
DB_BACKUP="${WT_DB_BACKUP:-true}"

# Hooks directory (for custom post-add scripts, etc.)
WT_HOOKS_DIR="${WT_HOOKS_DIR:-$HOME/.wt/hooks}"

# Templates directory (for worktree setup templates)
WT_TEMPLATES_DIR="${WT_TEMPLATES_DIR:-$HOME/.wt/templates}"

# Active template (set via --template flag)
WT_TEMPLATE=""

# Global flags
QUIET=false
FORCE=false
JSON_OUTPUT=false
PRETTY_JSON=false
DRY_RUN=false
DELETE_BRANCH=false
DROP_DB=false
NO_BACKUP=false
INTERACTIVE=false

# Parallel operations config
WT_MAX_PARALLEL="${WT_MAX_PARALLEL:-4}"

# Protected branches (cannot be removed without --force)
PROTECTED_BRANCHES="${WT_PROTECTED_BRANCHES:-staging main master}"

# Colour defaults (will be set properly by setup_colors)
C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN=""

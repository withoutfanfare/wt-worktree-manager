#!/usr/bin/env zsh
# 01-core.sh - Configuration loading, colours, output helpers

# Load config file safely (key=value parsing, not source)
load_config() {
  # Safe config parser - only allows whitelisted variables
  parse_config_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      # Skip comments and empty lines
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" || "$key" =~ ^[[:space:]]*$ ]] && continue

      # Trim whitespace from key
      key="${key#"${key%%[![:space:]]*}"}"
      key="${key%"${key##*[![:space:]]}"}"

      # Remove quotes and trailing comments from value
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"
      value="${value%%#*}"
      value="${value%"${value##*[![:space:]]}"}"

      # Only set whitelisted variables (security)
      case "$key" in
        HERD_ROOT) HERD_ROOT="$value" ;;
        HERD_CONFIG) HERD_CONFIG="$value" ;;
        DEFAULT_BASE) DEFAULT_BASE="$value" ;;
        DEFAULT_EDITOR) DEFAULT_EDITOR="$value" ;;
        WT_URL_SUBDOMAIN) WT_URL_SUBDOMAIN="$value" ;;
        WT_MAX_PARALLEL) WT_MAX_PARALLEL="$value" ;;
        DB_HOST) DB_HOST="$value" ;;
        DB_USER) DB_USER="$value" ;;
        DB_PASSWORD) DB_PASSWORD="$value" ;;
        DB_CREATE) DB_CREATE="$value" ;;
        DB_BACKUP_DIR) DB_BACKUP_DIR="$value" ;;
        DB_BACKUP) DB_BACKUP="$value" ;;
        WT_HOOKS_DIR) WT_HOOKS_DIR="$value" ;;
        WT_TEMPLATES_DIR) WT_TEMPLATES_DIR="$value" ;;
        PROTECTED_BRANCHES) PROTECTED_BRANCHES="$value" ;;
      esac
    done < "$file"
  }

  local config_file="${WT_CONFIG:-$HOME/.wtrc}"
  parse_config_file "$config_file"
  # Also check HERD_ROOT/.wtconfig
  parse_config_file "$HERD_ROOT/.wtconfig"
}

# Load repo-specific config from bare repo directory
# Called by commands that need repo-specific settings (add, sync, clone)
load_repo_config() {
  local git_dir="$1"
  local repo_config="$git_dir/.wtconfig"

  [[ -f "$repo_config" ]] || return 0

  # Re-use the parse_config_file function from load_config
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" || "$key" =~ ^[[:space:]]*$ ]] && continue

    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    value="${value%%#*}"
    value="${value%"${value##*[![:space:]]}"}"

    case "$key" in
      DEFAULT_BASE) DEFAULT_BASE="$value" ;;
      WT_URL_SUBDOMAIN) WT_URL_SUBDOMAIN="$value" ;;
      PROTECTED_BRANCHES) PROTECTED_BRANCHES="$value" ;;
    esac
  done < "$repo_config"
}

# Colours (disabled if not a tty or JSON output)
setup_colors() {
  if [[ -t 1 ]] && [[ "$JSON_OUTPUT" == false ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
  fi
}

die()  { print -r -- "${C_RED}✖ ERROR:${C_RESET} $*" >&2; exit 1; }
info() { [[ "$QUIET" == true ]] || print -r -- "${C_BLUE}→${C_RESET} $*"; }
ok()   { [[ "$QUIET" == true ]] || print -r -- "${C_GREEN}✔${C_RESET} $*"; }
warn() { print -r -- "${C_YELLOW}⚠${C_RESET} $*"; }
dim()  { [[ "$QUIET" == true ]] || print -r -- "${C_DIM}$*${C_RESET}"; }

# Error helper for worktree not found
die_wt_not_found() {
  local repo="$1" wt_path="$2"
  print -r -- "${C_RED}✖ ERROR:${C_RESET} Worktree not found at ${C_CYAN}$wt_path${C_RESET}" >&2
  print -r -- "" >&2
  print -r -- "  ${C_DIM}To see available worktrees, run:${C_RESET}" >&2
  print -r -- "    wt ls $repo" >&2
  print -r -- "" >&2
  exit 1
}

# macOS notification
notify() {
  local title="$1" message="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
  fi
}

# Confirmation helper
confirm() {
  local msg="$1"
  [[ "$FORCE" == true ]] && return 0

  print -n "${C_YELLOW}$msg [y/N]${C_RESET} "
  local response
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}

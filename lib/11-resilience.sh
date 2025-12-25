#!/usr/bin/env zsh
# 11-resilience.sh - Retry logic, transactions, disk checks, lock cleanup

# Retry a command with exponential backoff
# Usage: with_retry <max_attempts> <command...>
with_retry() {
  local max_attempts="$1"
  shift

  local attempt=1
  local delay=1

  while (( attempt <= max_attempts )); do
    if "$@"; then
      return 0
    fi

    if (( attempt < max_attempts )); then
      dim "  Attempt $attempt failed, retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))
    fi

    attempt=$((attempt + 1))
  done

  return 1
}

# Check for and optionally clean git index locks
# Usage: check_index_locks <git_dir> [--auto-clean]
check_index_locks() {
  local git_dir="$1"
  local auto_clean="${2:-}"
  local locks_found=0

  local worktrees_dir="$git_dir/worktrees"
  [[ -d "$worktrees_dir" ]] || return 0

  for lock_file in "$worktrees_dir"/*/index.lock(N); do
    [[ -f "$lock_file" ]] || continue

    # Check if lock is stale (older than 5 minutes and no git process)
    local lock_age=$(($(date +%s) - $(stat -f %m "$lock_file" 2>/dev/null || echo 0)))
    if (( lock_age > 300 )); then
      if [[ "$auto_clean" == "--auto-clean" ]]; then
        rm -f "$lock_file"
        dim "  Removed stale lock: ${lock_file##*/worktrees/}"
      else
        warn "Stale lock found: ${lock_file##*/worktrees/}"
        locks_found=$((locks_found + 1))
      fi
    fi
  done

  return $locks_found
}

# Check available disk space
# Usage: check_disk_space <path> <min_mb>
check_disk_space() {
  local path="$1"
  local min_mb="${2:-1024}"  # Default 1GB

  local available_kb
  available_kb=$(df -k "$path" 2>/dev/null | tail -1 | awk '{print $4}')
  local available_mb=$((available_kb / 1024))

  if (( available_mb < min_mb )); then
    die "Insufficient disk space: ${available_mb}MB available, ${min_mb}MB required"
  fi
}

# Transaction state
typeset -g WT_TRANSACTION_ACTIVE=false
typeset -g WT_ROLLBACK_STEPS=()

# Start a transaction
transaction_start() {
  WT_TRANSACTION_ACTIVE=true
  WT_ROLLBACK_STEPS=()
  trap 'transaction_rollback' EXIT INT TERM
}

# Register rollback step
transaction_register() {
  WT_ROLLBACK_STEPS+=("$1")
}

# Commit transaction (disable rollback)
transaction_commit() {
  WT_TRANSACTION_ACTIVE=false
  WT_ROLLBACK_STEPS=()
  trap - EXIT INT TERM
}

# Rollback on failure
transaction_rollback() {
  [[ "$WT_TRANSACTION_ACTIVE" == true ]] || return 0

  warn "Rolling back failed operation..."

  # Execute rollback steps in reverse order
  local i
  for ((i=${#WT_ROLLBACK_STEPS[@]}-1; i>=0; i--)); do
    local step="${WT_ROLLBACK_STEPS[$i]}"
    eval "$step" 2>/dev/null || true
  done

  WT_TRANSACTION_ACTIVE=false
}

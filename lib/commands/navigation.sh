#!/usr/bin/env zsh
# navigation.sh - Navigation and editor commands

cmd_code() {
  local repo="${1:-}"; local branch="${2:-}"

  # Auto-detect from current directory if no args
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    branch="$DETECTED_BRANCH"
  fi

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree to open")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt code [<repo> [<branch>]]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"

  local editor="$DEFAULT_EDITOR"

  # Detect available editor
  if ! command -v "$editor" >/dev/null 2>&1; then
    if command -v cursor >/dev/null 2>&1; then
      editor="cursor"
    elif command -v code >/dev/null 2>&1; then
      editor="code"
    else
      die "No editor found. Install VS Code or Cursor, or set WT_EDITOR"
    fi
  fi

  info "Opening in ${C_BOLD}$editor${C_RESET}..."
  "$editor" "$wt_path"
}

cmd_open() {
  local repo="${1:-}"; local branch="${2:-}"

  # Auto-detect from current directory if no args
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    branch="$DETECTED_BRANCH"
  fi

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree to open")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt open [<repo> [<branch>]]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  # Get actual worktree path
  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"

  # Read APP_URL from .env file, fall back to folder-based URL
  local url=""
  if [[ -f "$wt_path/.env" ]]; then
    url="$(grep -E '^APP_URL=' "$wt_path/.env" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/#.*//' | tr -d '"' | tr -d "'" | tr -d ' ')"
  fi

  # Fallback to folder-based URL if APP_URL not found
  if [[ -z "$url" ]]; then
    local folder="${wt_path:t}"
    url="https://${folder}.test"
    dim "  No APP_URL in .env, using: $url"
  fi

  command -v open >/dev/null 2>&1 || die "'open' command not found (macOS expected)"
  open "$url"
}

cmd_cd() {
  local repo="${1:-}"; local branch="${2:-}"

  # Auto-detect from current directory if no args
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    branch="$DETECTED_BRANCH"
  fi

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt cd [<repo> [<branch>]]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  resolve_wt_path "$repo" "$branch"
}

cmd_switch() {
  local repo="${1:-}"; local branch="${2:-}"

  # Note: No auto-detect for switch - it's meant to switch TO a different worktree

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree to switch to")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt switch <repo> [<branch>]"

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"

  # Read APP_URL from .env file, fall back to folder-based URL
  local url=""
  if [[ -f "$wt_path/.env" ]]; then
    url="$(grep -E '^APP_URL=' "$wt_path/.env" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/#.*//' | tr -d '"' | tr -d "'" | tr -d ' ')"
  fi
  if [[ -z "$url" ]]; then
    local folder="${wt_path:t}"
    url="https://${folder}.test"
  fi

  # Print path for cd (user can use: cd "$(wt switch ...)")
  print -r -- "$wt_path"

  # Open in editor
  local editor="$DEFAULT_EDITOR"
  if command -v "$editor" >/dev/null 2>&1; then
    "$editor" "$wt_path" &
  fi

  # Open in browser
  if command -v open >/dev/null 2>&1; then
    open "$url" &
  fi
}

cmd_exec() {
  local repo="${1:-}"; local branch="${2:-}"
  shift 2 2>/dev/null || die "Usage: wt exec <repo> <branch> <command...>"
  local cmd=("$@")

  [[ -n "$repo" && -n "$branch" && ${#cmd[@]} -gt 0 ]] || die "Usage: wt exec <repo> <branch> <command...>"

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local wt_path
  wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die "Worktree not found at $wt_path"

  pushd "$wt_path" >/dev/null || die "Failed to cd into $wt_path"
  "${cmd[@]}"
  popd >/dev/null
}

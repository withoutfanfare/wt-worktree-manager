#!/usr/bin/env zsh
# laravel.sh - Laravel-specific commands

cmd_migrate() {
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

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt migrate [<repo> [<branch>]]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"
  [[ -f "$wt_path/artisan" ]] || die "Not a Laravel project (no artisan file)"

  pushd "$wt_path" >/dev/null || die "Failed to cd into $wt_path"
  php artisan migrate
  popd >/dev/null
}

cmd_tinker() {
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

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt tinker [<repo> [<branch>]]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"
  [[ -f "$wt_path/artisan" ]] || die "Not a Laravel project (no artisan file)"

  pushd "$wt_path" >/dev/null || die "Failed to cd into $wt_path"
  php artisan tinker
  popd >/dev/null
}

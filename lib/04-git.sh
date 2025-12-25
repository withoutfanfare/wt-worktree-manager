#!/usr/bin/env zsh
# 04-git.sh - Git operations and repository helpers

ensure_bare_repo() {
  local git_dir="$1"
  [[ -d "$git_dir" ]] || die "Bare repo not found at $git_dir"
}

# List all repos in HERD_ROOT
list_repos() {
  for dir in "$HERD_ROOT"/*.git(N); do
    [[ -d "$dir" ]] && print -r -- "${${dir:t}%.git}"
  done
}

# List all worktree branches for a repo
list_worktree_branches() {
  local repo="$1"
  local git_dir; git_dir="$(git_dir_for "$repo")"
  [[ -d "$git_dir" ]] || return 0

  git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null | \
    grep '^branch refs/heads/' | \
    sed 's|^branch refs/heads/||'
}

# Interactive branch selection with fzf
select_branch_fzf() {
  local repo="$1" prompt="${2:-Select branch}"
  local git_dir; git_dir="$(git_dir_for "$repo")"

  if ! command -v fzf >/dev/null 2>&1; then
    die "fzf not installed. Install with: brew install fzf"
  fi

  local branches; branches="$(list_worktree_branches "$repo")"
  [[ -n "$branches" ]] || die "No worktrees found for $repo"

  print -r -- "$branches" | fzf --prompt="$prompt: " --height=40% --reverse
}

# Interactive repo selection with fzf
select_repo_fzf() {
  local prompt="${1:-Select repository}"

  if ! command -v fzf >/dev/null 2>&1; then
    die "fzf not installed. Install with: brew install fzf"
  fi

  local repos; repos="$(list_repos)"
  [[ -n "$repos" ]] || die "No repositories found in $HERD_ROOT"

  print -r -- "$repos" | fzf --prompt="$prompt: " --height=40% --reverse
}

# Get ahead/behind counts for a branch
get_ahead_behind() {
  local wt_path="$1" base="${2:-origin/staging}"
  local ahead=0 behind=0

  if git -C "$wt_path" rev-parse --verify "$base" >/dev/null 2>&1; then
    local counts; counts="$(git -C "$wt_path" rev-list --left-right --count HEAD..."$base" 2>/dev/null)" || counts="0	0"
    ahead="${counts%%	*}"
    behind="${counts##*	}"
  fi

  print -r -- "$ahead $behind"
}

# Check if branch is stale (significantly behind base)
check_stale() {
  local wt_path="$1" base="${2:-origin/staging}" threshold="${3:-50}"
  local counts; counts="$(get_ahead_behind "$wt_path" "$base")"
  local behind="${counts##* }"

  if (( behind > threshold )); then
    warn "Branch is ${C_BOLD}$behind${C_RESET}${C_YELLOW} commits behind ${C_DIM}$base${C_RESET}"
    return 0
  fi
  return 1
}

# Get human-readable age of last commit
# Returns: "1d", "2w", "3mo", "1y" etc.
get_last_commit_age() {
  local wt_path="$1"
  local now epoch_seconds age_seconds age_days

  now="$(date +%s)"
  epoch_seconds="$(git -C "$wt_path" log -1 --format=%ct 2>/dev/null)" || { print -r -- "?"; return 0; }

  # Handle future timestamps (clock skew, timezone issues)
  if (( epoch_seconds > now )); then
    print -r -- "<1h"
    return 0
  fi

  (( age_seconds = now - epoch_seconds ))
  (( age_days = age_seconds / 86400 ))

  if (( age_days == 0 )); then
    local hours=$(( age_seconds / 3600 ))
    if (( hours == 0 )); then
      print -r -- "<1h"
    else
      print -r -- "${hours}h"
    fi
  elif (( age_days < 7 )); then
    print -r -- "${age_days}d"
  elif (( age_days < 30 )); then
    print -r -- "$(( age_days / 7 ))w"
  elif (( age_days < 365 )); then
    print -r -- "$(( age_days / 30 ))mo"
  else
    print -r -- "$(( age_days / 365 ))y"
  fi
}

# Get age in days (for threshold comparison)
get_commit_age_days() {
  local wt_path="$1"
  local now epoch_seconds age_seconds

  now="$(date +%s)"
  epoch_seconds="$(git -C "$wt_path" log -1 --format=%ct 2>/dev/null)" || { print -r -- "0"; return 0; }

  # Handle future timestamps (clock skew, timezone issues)
  if (( epoch_seconds > now )); then
    print -r -- "0"
    return 0
  fi

  (( age_seconds = now - epoch_seconds ))
  print -r -- "$(( age_seconds / 86400 ))"
}

# Check if branch is fully merged into base
is_branch_merged() {
  local wt_path="$1" base="${2:-origin/staging}"
  local branch_head base_head

  branch_head="$(git -C "$wt_path" rev-parse HEAD 2>/dev/null)" || return 1

  # Check if the base branch contains this commit
  if git -C "$wt_path" merge-base --is-ancestor "$branch_head" "$base" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Collect worktrees for a repo into an array
# Usage: collect_worktrees "$git_dir" worktrees_array
collect_worktrees() {
  local git_dir="$1"
  local -n result_array="$2"
  result_array=()

  local out; out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || return 0

  local path="" branch="" line=""
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      if [[ -n "$path" && -n "$branch" && "$path" != *.git ]]; then
        result_array+=("$path|$branch")
      fi
      path=""
      branch=""
      continue
    fi
    [[ "$line" == worktree\ * ]] && path="${line#worktree }"
    [[ "$line" == branch\ refs/heads/* ]] && branch="${line#branch refs/heads/}"
  done <<< "$out"

  # Handle last entry
  if [[ -n "$path" && -n "$branch" && "$path" != *.git ]]; then
    result_array+=("$path|$branch")
  fi
}

#!/usr/bin/env zsh
# 03-paths.sh - Path resolution, worktree detection, URL generation

sed_inplace() {
  local pattern="$1" file="$2"
  if sed --version 2>&1 | grep -q GNU; then
    sed -i "$pattern" "$file"
  else
    sed -i '' "$pattern" "$file"
  fi
}

slugify_branch() {
  local b="$1"
  print -r -- "${b//\//-}"
}

# Extract feature name from branch (strips prefixes like feature/, bugfix/, etc.)
# e.g., "feature/sms-unsubscribe" -> "sms-unsubscribe"
# e.g., "feature/dh/uat/build-test" -> "build-test" (takes last segment)
# e.g., "staging" -> "staging" (unchanged if no prefix)
extract_feature_name() {
  local branch="$1"
  local result="$branch"

  # If branch contains a slash, extract the last segment
  if [[ "$branch" == */* ]]; then
    result="${branch##*/}"
  fi

  print -r -- "$result"
}

# Check if worktree directory name matches the branch it's on
# Returns: "ok", "skip", or "mismatch|expected_slug" (pipe-separated for mismatch)
check_branch_directory_match() {
  local wt_path="$1"
  local actual_branch="$2"
  local repo="$3"

  # Skip bare repo and main worktree (e.g., scooda for staging)
  local folder="${wt_path:t}"
  if [[ "$folder" != *"--"* ]]; then
    print -r -- "skip"
    return 0
  fi

  # Extract the slug from directory name (part after repo--)
  local dir_slug="${folder#*--}"

  # Slugify the actual branch
  local branch_slug; branch_slug="$(slugify_branch "$actual_branch")"

  if [[ "$dir_slug" != "$branch_slug" ]]; then
    print -r -- "mismatch|$branch_slug"
  else
    print -r -- "ok"
  fi
}

# Look up actual worktree path from git by branch name
# Returns empty string if not found
lookup_wt_path() {
  local repo="$1"
  local branch="$2"
  local git_dir; git_dir="$(git_dir_for "$repo")"

  [[ -d "$git_dir" ]] || return 0

  local out; out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || return 0

  local path="" current_branch="" line=""
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      if [[ "$current_branch" == "$branch" && -n "$path" ]]; then
        print -r -- "$path"
        return 0
      fi
      path=""
      current_branch=""
      continue
    fi
    [[ "$line" == worktree\ * ]] && path="${line#worktree }"
    [[ "$line" == branch\ refs/heads/* ]] && current_branch="${line#branch refs/heads/}"
  done <<< "$out"

  # Handle last entry (no trailing blank line)
  if [[ "$current_branch" == "$branch" && -n "$path" ]]; then
    print -r -- "$path"
    return 0
  fi

  return 0
}

# Get worktree path - tries lookup first, falls back to computed path
resolve_wt_path() {
  local repo="$1"
  local branch="$2"

  # First try to look up actual path from git
  local actual_path; actual_path="$(lookup_wt_path "$repo" "$branch")"
  if [[ -n "$actual_path" ]]; then
    print -r -- "$actual_path"
    return 0
  fi

  # Fall back to computed path (for new worktrees)
  wt_path_for "$repo" "$branch"
}

# Auto-detect repo and branch from current directory
# Sets DETECTED_REPO and DETECTED_BRANCH globals
# Returns 0 if detected, 1 if not in a worktree
detect_current_worktree() {
  DETECTED_REPO=""
  DETECTED_BRANCH=""

  # Check if we're in a git directory
  local git_dir; git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 1

  # Get the worktree root
  local wt_root; wt_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1

  # Check if the worktree is under HERD_ROOT
  [[ "$wt_root" == "$HERD_ROOT"/* ]] || return 1

  # Get the folder name
  local folder="${wt_root:t}"

  # Try to find the bare repo by checking the git-dir path
  # For worktrees, git-dir is like: /path/to/repo.git/worktrees/worktree-name
  if [[ "$git_dir" == *"/worktrees/"* ]]; then
    # Extract bare repo path
    local bare_repo="${git_dir%/worktrees/*}"
    DETECTED_REPO="${${bare_repo:t}%.git}"
  elif [[ -d "$HERD_ROOT/${folder}.git" ]]; then
    # This is a main worktree (like staging) - folder name matches repo
    DETECTED_REPO="$folder"
  else
    # Try to extract repo from folder name (repo--slug pattern)
    if [[ "$folder" == *"--"* ]]; then
      DETECTED_REPO="${folder%%--*}"
    else
      return 1
    fi
  fi

  # Verify the bare repo exists
  [[ -d "$HERD_ROOT/${DETECTED_REPO}.git" ]] || return 1

  # Get the current branch
  DETECTED_BRANCH="$(git branch --show-current 2>/dev/null)" || return 1
  [[ -n "$DETECTED_BRANCH" ]] || return 1

  return 0
}

# Helper to require repo argument, with auto-detection fallback
require_repo() {
  local repo="$1"
  if [[ -z "$repo" ]]; then
    if detect_current_worktree; then
      print -r -- "$DETECTED_REPO"
      return 0
    fi
    return 1
  fi
  print -r -- "$repo"
}

# Helper to require repo and branch, with auto-detection fallback
require_repo_branch() {
  local repo="$1"
  local branch="$2"

  if [[ -z "$repo" ]]; then
    if detect_current_worktree; then
      print -r -- "$DETECTED_REPO $DETECTED_BRANCH"
      return 0
    fi
    return 1
  fi

  if [[ -z "$branch" ]]; then
    # Repo provided but no branch - use fzf or fail
    return 1
  fi

  print -r -- "$repo $branch"
}

git_dir_for() {
  local repo="$1"
  print -r -- "$HERD_ROOT/${repo}.git"
}

wt_path_for() {
  local repo="$1"
  local branch="$2"
  local slug; slug="$(slugify_branch "$branch")"
  print -r -- "$HERD_ROOT/${repo}--${slug}"
}

url_for() {
  local repo="$1"
  local branch="$2"
  local slug; slug="$(slugify_branch "$branch")"
  local site_name="${repo}--${slug}"

  # Build URL: [subdomain.]site-name.test
  # Site name matches the directory name used by Herd
  if [[ -n "$WT_URL_SUBDOMAIN" ]]; then
    print -r -- "https://${WT_URL_SUBDOMAIN}.${site_name}.test"
  else
    print -r -- "https://${site_name}.test"
  fi
}

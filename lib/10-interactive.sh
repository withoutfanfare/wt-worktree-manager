#!/usr/bin/env zsh
# 10-interactive.sh - Interactive worktree creation wizard

# Interactive worktree creation
# Usage: interactive_add [repo]
interactive_add() {
  local initial_repo="${1:-}"

  # Ensure fzf is available
  if ! command -v fzf >/dev/null 2>&1; then
    die "Interactive mode requires fzf. Install with: brew install fzf"
  fi

  print -r -- ""
  print -r -- "${C_BOLD}🌳 Interactive Worktree Creation${C_RESET}"
  print -r -- ""

  # Step 1: Repository selection
  local repo="$initial_repo"
  if [[ -z "$repo" ]]; then
    print -r -- "${C_BOLD}Step 1/5:${C_RESET} Select repository"
    local repos; repos="$(list_repos)"
    [[ -n "$repos" ]] || die "No repositories found in $HERD_ROOT"

    repo="$(echo "$repos" | fzf --prompt="Repository: " --height=40% --reverse)"
    [[ -n "$repo" ]] || die "No repository selected"
  fi

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"
  load_repo_config "$git_dir"

  ok "Repository: ${C_CYAN}$repo${C_RESET}"
  print -r -- ""

  # Step 2: Base branch selection
  print -r -- "${C_BOLD}Step 2/5:${C_RESET} Select base branch"

  # Fetch first
  with_spinner "Fetching branches" git --git-dir="$git_dir" fetch --all --prune --quiet

  # Get remote branches for selection
  local branches; branches="$(git --git-dir="$git_dir" branch -r --format='%(refname:short)' 2>/dev/null | grep -v HEAD)"

  local base
  base="$(echo "$branches" | fzf --prompt="Base branch: " --height=40% --reverse --query="origin/staging")"
  [[ -n "$base" ]] || base="$DEFAULT_BASE"

  ok "Base: ${C_DIM}$base${C_RESET}"
  print -r -- ""

  # Step 3: Branch name input with live preview
  print -r -- "${C_BOLD}Step 3/5:${C_RESET} Enter new branch name"
  print -r -- "${C_DIM}  (e.g., feature/my-feature, bugfix/fix-123)${C_RESET}"
  print -r -- ""

  local branch=""
  while [[ -z "$branch" ]]; do
    print -n "  Branch name: "
    read -r branch

    if [[ -z "$branch" ]]; then
      warn "Branch name required"
      continue
    fi

    # Validate
    if ! validate_name "$branch" "branch" 2>/dev/null; then
      warn "Invalid branch name"
      branch=""
      continue
    fi

    # Check if already exists
    if git --git-dir="$git_dir" show-ref --quiet "refs/heads/$branch" 2>/dev/null; then
      warn "Branch already exists: $branch"
      branch=""
      continue
    fi
  done

  # Show preview
  local wt_path; wt_path="$(wt_path_for "$repo" "$branch")"
  local app_url; app_url="$(url_for "$repo" "$branch")"
  local db_name; db_name="$(db_name_for "$repo" "$branch")"

  print -r -- ""
  print -r -- "  ${C_DIM}Preview:${C_RESET}"
  print -r -- "    Path:     ${C_CYAN}$wt_path${C_RESET}"
  print -r -- "    URL:      ${C_BLUE}$app_url${C_RESET}"
  print -r -- "    Database: ${C_CYAN}$db_name${C_RESET}"
  print -r -- ""

  # Step 4: Template selection (optional)
  print -r -- "${C_BOLD}Step 4/5:${C_RESET} Select template ${C_DIM}(optional)${C_RESET}"

  local template=""
  local templates; templates="$(get_template_names)"

  if [[ -n "$templates" ]]; then
    # Add "none" option
    templates="(none)
$templates"

    template="$(echo "$templates" | fzf --prompt="Template: " --height=40% --reverse)"

    if [[ "$template" != "(none)" && -n "$template" ]]; then
      WT_TEMPLATE="$template"
      ok "Template: ${C_CYAN}$template${C_RESET}"
    else
      dim "  No template selected"
    fi
  else
    dim "  No templates available"
  fi
  print -r -- ""

  # Step 5: Confirmation
  print -r -- "${C_BOLD}Step 5/5:${C_RESET} Confirm"
  print -r -- ""
  print -r -- "  ${C_BOLD}Summary:${C_RESET}"
  print -r -- "    Repository: ${C_CYAN}$repo${C_RESET}"
  print -r -- "    Branch:     ${C_MAGENTA}$branch${C_RESET}"
  print -r -- "    Base:       ${C_DIM}$base${C_RESET}"
  print -r -- "    Path:       $wt_path"
  print -r -- "    URL:        ${C_BLUE}$app_url${C_RESET}"
  [[ -n "$WT_TEMPLATE" ]] && print -r -- "    Template:   ${C_CYAN}$WT_TEMPLATE${C_RESET}"
  print -r -- ""

  print -n "  ${C_GREEN}Create worktree? [Y/n]${C_RESET} "
  local response; read -r response

  if [[ "$response" =~ ^[Nn]$ ]]; then
    dim "Aborted"
    return 0
  fi

  print -r -- ""

  # Execute creation (call cmd_add with collected params)
  INTERACTIVE=false  # Disable interactive mode for actual creation
  cmd_add "$repo" "$branch" "$base"
}

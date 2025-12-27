#!/usr/bin/env zsh
# 02-validation.sh - Input validation and security checks

# Check if branch is protected
is_protected_branch() {
  local branch="$1"
  local protected
  for protected in ${=PROTECTED_BRANCHES}; do
    [[ "$branch" == "$protected" ]] && return 0
  done
  return 1
}

# Config validation
validate_config() {
  local warnings=0

  # Check HERD_ROOT exists
  if [[ ! -d "$HERD_ROOT" ]]; then
    warn "HERD_ROOT does not exist: $HERD_ROOT"
    warnings=$((warnings + 1))
  fi

  # Check for required tools (only warn, don't fail)
  if ! command -v git >/dev/null 2>&1; then
    warn "git not found in PATH"
    warnings=$((warnings + 1))
  fi

  return $warnings
}

# Common validation helper for identifiers (repos, branches, templates)
# Usage: validate_identifier <value> <type> <allowed_chars_regex> [extra_checks]
# Returns 0 on success, calls die on failure
validate_identifier_common() {
  local input="$1" type="$2"

  # Block empty or whitespace-only
  if [[ -z "$input" || "$input" =~ ^[[:space:]]*$ ]]; then
    die "Invalid $type: name cannot be empty"
  fi

  # Block path traversal
  if [[ "$input" == *".."* ]]; then
    die "Invalid $type: '$input' (path traversal not allowed)"
  fi

  # Block names starting with dash (flag injection)
  if [[ "$input" == -* ]]; then
    die "Invalid $type: '$input' (cannot start with dash)"
  fi
}

validate_name() {
  local input="$1" type="$2"

  validate_identifier_common "$input" "$type"

  # Block absolute paths
  if [[ "$input" == /* ]]; then
    die "Invalid $type name: '$input' (absolute paths not allowed)"
  fi

  # Block hidden path segments
  if [[ "$input" == *"/."* || "$input" == *"/./"* ]]; then
    die "Invalid $type name: '$input' (path traversal not allowed)"
  fi

  # Block reserved git references
  if [[ "$type" == "branch" && "$input" =~ ^(HEAD|refs/|@).*$ ]]; then
    die "Invalid $type name: '$input' (reserved git reference)"
  fi

  # Allow alphanumeric, dash, underscore, forward slash, dot
  if [[ ! "$input" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
    die "Invalid $type name: '$input' (only alphanumeric, dash, underscore, slash, dot allowed)"
  fi

  # Block empty segments in paths
  if [[ "$input" =~ // || "$input" =~ /$ ]]; then
    die "Invalid $type name: '$input' (malformed path)"
  fi
}

# Validate branch name against configured pattern
# Usage: validate_branch_pattern <branch_name>
# Uses BRANCH_PATTERN from config (optional)
validate_branch_pattern() {
  local branch="$1"

  # Skip if no pattern configured
  [[ -z "${BRANCH_PATTERN:-}" ]] && return 0

  # Check against pattern
  if [[ ! "$branch" =~ $BRANCH_PATTERN ]]; then
    local suggestion=""

    # Try to suggest a fix
    local clean_branch="${branch//[^a-z0-9\/\-]/-}"  # Replace invalid chars
    clean_branch="${clean_branch:l}"  # Lowercase
    clean_branch="${clean_branch//--/-}"  # Remove double dashes

    # Try common prefixes
    if [[ ! "$branch" =~ ^(feature|bugfix|hotfix|release)/ ]]; then
      suggestion="feature/${clean_branch##*/}"
    else
      suggestion="$clean_branch"
    fi

    local error_msg="Branch name '${C_RED}$branch${C_RESET}' doesn't match required pattern"
    error_msg+="\n\n${C_DIM}Pattern:${C_RESET} $BRANCH_PATTERN"
    error_msg+="\n${C_DIM}Example:${C_RESET} feature/my-feature, bugfix/fix-login"

    if [[ "$suggestion" != "$branch" ]]; then
      error_msg+="\n\n${C_YELLOW}Suggestion:${C_RESET} $suggestion"
    fi

    error_msg+="\n\n${C_DIM}Use --force to bypass this check${C_RESET}"

    if [[ "${FORCE:-false}" != true ]]; then
      die "$error_msg"
    else
      warn "Branch name doesn't match pattern (bypassed with --force)"
    fi
  fi
}

# Auto-fix common branch name issues
# Usage: normalize_branch_name <branch_name>
normalize_branch_name() {
  local branch="$1"

  # Replace spaces with dashes
  branch="${branch// /-}"

  # Lowercase
  branch="${branch:l}"

  # Remove consecutive dashes
  while [[ "$branch" == *"--"* ]]; do
    branch="${branch//--/-}"
  done

  # Remove leading/trailing dashes from segments
  branch="${branch#-}"
  branch="${branch%-}"

  print -r -- "$branch"
}

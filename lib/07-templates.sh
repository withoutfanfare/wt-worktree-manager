#!/usr/bin/env zsh
# 07-templates.sh - Template loading and listing

# Validate template name (security: prevent path traversal)
validate_template_name() {
  local name="$1"

  validate_identifier_common "$name" "template"

  # Block slashes and backslashes (templates are single files, no paths)
  if [[ "$name" == *"/"* || "$name" == *"\\"* ]]; then
    die "Invalid template name: '$name' (path separators not allowed)"
  fi

  # Only allow alphanumeric, dash, underscore (stricter than repo/branch names)
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    die "Invalid template name: '$name' (only alphanumeric, dash, underscore allowed)"
  fi
}

# Extract TEMPLATE_DESC from a template file
# Usage: extract_template_desc "/path/to/template.conf"
extract_template_desc() {
  local file="$1"
  grep '^TEMPLATE_DESC=' "$file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d "\"'"
}

# Find similar names for "did you mean?" suggestions
# Usage: suggest_similar <input> <type> <list_of_options>
# Returns the closest match or empty string
suggest_similar() {
  local input="$1" type="$2"
  shift 2
  local options=("$@")
  local best_match="" best_score=999

  for opt in "${options[@]}"; do
    # Simple similarity: count matching characters at start
    local i=0 score=0
    local input_lower="${input:l}" opt_lower="${opt:l}"

    # Check if input is a prefix
    if [[ "$opt_lower" == "$input_lower"* ]]; then
      score=$((${#opt} - ${#input}))
      if (( score < best_score )); then
        best_score=$score
        best_match="$opt"
      fi
      continue
    fi

    # Check if input is a substring
    if [[ "$opt_lower" == *"$input_lower"* ]]; then
      score=$((${#opt} - ${#input} + 5))
      if (( score < best_score )); then
        best_score=$score
        best_match="$opt"
      fi
      continue
    fi

    # Levenshtein-like: count character differences (simplified)
    local len1=${#input_lower} len2=${#opt_lower}
    local max_len=$(( len1 > len2 ? len1 : len2 ))
    local matching=0
    for (( i=0; i < max_len; i++ )); do
      [[ "${input_lower:$i:1}" == "${opt_lower:$i:1}" ]] && ((matching++))
    done
    score=$((max_len - matching))
    if (( score < best_score && score < max_len / 2 )); then
      best_score=$score
      best_match="$opt"
    fi
  done

  # Only suggest if reasonably close (within half the length)
  if [[ -n "$best_match" && $best_score -lt ${#input} ]]; then
    print -r -- "$best_match"
  fi
}

# Get list of available template names
get_template_names() {
  local templates=()
  if [[ -d "$WT_TEMPLATES_DIR" ]]; then
    for f in "$WT_TEMPLATES_DIR"/*.conf(N); do
      templates+=("${f:t:r}")
    done
  fi
  print -r -- "${templates[@]}"
}

load_template() {
  local template_name="$1"

  # Validate template name first (security: prevent path traversal)
  validate_template_name "$template_name"

  local template_file="$WT_TEMPLATES_DIR/${template_name}.conf"

  # Check if template exists
  if [[ ! -f "$template_file" ]]; then
    local available_templates
    available_templates=($(get_template_names))

    local suggestion=""
    if (( ${#available_templates[@]} > 0 )); then
      suggestion="$(suggest_similar "$template_name" "template" "${available_templates[@]}")"
    fi

    local error_msg="Template not found: ${C_CYAN}$template_name${C_RESET}"
    if [[ -n "$suggestion" ]]; then
      error_msg+="\n\n  ${C_YELLOW}Did you mean:${C_RESET} ${C_GREEN}$suggestion${C_RESET}?"
    fi
    error_msg+="\n\n${C_DIM}Available templates:${C_RESET}\n$(list_templates 2>&1)"
    error_msg+="\n\n${C_DIM}Run 'wt templates' to see all templates${C_RESET}"

    die "$error_msg"
  fi

  # Parse template file (only allow WT_SKIP_* and TEMPLATE_DESC)
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

    # Only allow WT_SKIP_* variables with true/false values (security)
    case "$key" in
      WT_SKIP_*)
        # Security: Only allow true/false values to prevent command injection
        if [[ "$value" != "true" && "$value" != "false" ]]; then
          warn "Invalid value for $key: '$value' (must be true or false) - skipping"
          continue
        fi
        export "$key"="$value"
        ;;
      TEMPLATE_DESC) ;; # Ignore, used for display only
      *) ;; # Ignore other variables (security)
    esac
  done < "$template_file"

  dim "  Applied template: $template_name"
}

# List available templates
list_templates() {
  local templates_found=false

  if [[ -d "$WT_TEMPLATES_DIR" ]]; then
    for f in "$WT_TEMPLATES_DIR"/*.conf(N); do
      templates_found=true
      local name="${f:t:r}"  # Remove path and .conf extension
      local desc=""

      # Extract TEMPLATE_DESC if present
      desc="$(extract_template_desc "$f")"

      if [[ -n "$desc" ]]; then
        print -r -- "  $name - $desc"
      else
        print -r -- "  $name"
      fi
    done
  fi

  if [[ "$templates_found" != true ]]; then
    print -r -- "  (no templates found)"
    print -r -- ""
    print -r -- "  Create templates in: $WT_TEMPLATES_DIR/"
    print -r -- "  Example: $WT_TEMPLATES_DIR/laravel.conf"
  fi
}

# JSON helper
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"       # Backslash must be first
  s="${s//\"/\\\"}"       # Double quote
  s="${s//$'\n'/\\n}"     # Newline
  s="${s//$'\t'/\\t}"     # Tab
  s="${s//$'\r'/\\r}"     # Carriage return
  s="${s//$'\f'/\\f}"     # Form feed
  s="${s//$'\b'/\\b}"     # Backspace
  print -r -- "$s"
}

# Pretty-print JSON with colours and indentation
# Usage: format_json "$json_string"
format_json() {
  local json="$1"

  if [[ "$PRETTY_JSON" != true ]]; then
    print -r -- "$json"
    return
  fi

  # Use jq or python3 for proper JSON formatting if available, with fallback to simple approach
  local result="$json"
  local formatted=""

  if command -v jq >/dev/null 2>&1; then
    if formatted="$(print -r -- "$json" | jq . 2>/dev/null)"; then
      result="$formatted"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if formatted="$(print -r -- "$json" | python3 -m json.tool 2>/dev/null)"; then
      result="$formatted"
    fi
  else
    # Fallback: simple string replacements for basic formatting
    result="${result//\[/$'\n['}"
    result="${result//\{/$'\n  {'}"
    result="${result//\}/$'}\n'}"
    result="${result//\],/$'],\n'}"
    result="${result//\}, /'},\n  '}"
  fi

  # Apply colours if terminal supports it
  if [[ -t 1 ]]; then
    # Colour keys (words before colons)
    result="$(print -r -- "$result" | sed -E "s/\"([^\"]+)\":/\"${C_CYAN}\1${C_RESET}\":/g")"
    # Colour string values
    result="$(print -r -- "$result" | sed -E "s/: \"([^\"]*)\"/: \"${C_GREEN}\1${C_RESET}\"/g")"
    # Colour booleans
    result="${result//: true/: ${C_MAGENTA}true${C_RESET}}"
    result="${result//: false/: ${C_MAGENTA}false${C_RESET}}"
    # Colour numbers (simple approach)
    result="$(print -r -- "$result" | sed -E "s/: ([0-9]+)([,}])/: ${C_YELLOW}\1${C_RESET}\2/g")"
  fi

  print -r -- "$result"
}

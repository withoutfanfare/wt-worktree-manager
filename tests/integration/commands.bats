#!/usr/bin/env bats
# commands.bats - Integration tests for wt commands
#
# These tests verify command-line parsing, help output, and validation
# without requiring a full git repository setup

load '../test-helper'

setup() {
  setup_test_environment

  # Export WT script path for testing
  export WT_SCRIPT="$WT_ROOT/wt"

  # Create templates directory with test templates
  mkdir -p "$TEST_TEMP_DIR/.wt/templates"

  cat > "$TEST_TEMP_DIR/.wt/templates/laravel.conf" << 'EOF'
TEMPLATE_DESC="Laravel full setup"
WT_SKIP_DB=false
WT_SKIP_COMPOSER=false
EOF

  cat > "$TEST_TEMP_DIR/.wt/templates/node.conf" << 'EOF'
TEMPLATE_DESC="Node.js only"
WT_SKIP_COMPOSER=true
WT_SKIP_DB=true
EOF

  cat > "$TEST_TEMP_DIR/.wt/templates/minimal.conf" << 'EOF'
TEMPLATE_DESC="Minimal setup"
WT_SKIP_DB=true
WT_SKIP_NPM=true
WT_SKIP_COMPOSER=true
WT_SKIP_BUILD=true
WT_SKIP_MIGRATE=true
WT_SKIP_HERD=true
EOF
}

teardown() {
  teardown_test_environment
}

# Helper to run wt with test environment
run_wt() {
  HERD_ROOT="$HERD_ROOT" \
  WT_HOOKS_DIR="$WT_HOOKS_DIR" \
  WT_TEMPLATES_DIR="$TEST_TEMP_DIR/.wt/templates" \
  NO_COLOR=1 \
  run zsh "$WT_SCRIPT" "$@"
}

# ============================================================================
# Help and version
# ============================================================================

@test "wt --help: shows usage information" {
  run_wt --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"CORE COMMANDS"* ]]
}

@test "wt --version: shows version number" {
  run_wt --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"wt version"* ]]
  [[ "$output" == *"3."* ]]
}

@test "wt help: shows usage (alternative syntax)" {
  run_wt help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "wt --help: lists available templates" {
  run_wt --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"AVAILABLE TEMPLATES"* ]]
  [[ "$output" == *"laravel"* ]]
  [[ "$output" == *"node"* ]]
  [[ "$output" == *"minimal"* ]]
}

@test "wt --help: shows new flags" {
  run_wt --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--pretty"* ]]
  [[ "$output" == *"--template"* ]]
}

# ============================================================================
# wt templates - Template management
# ============================================================================

@test "wt templates: lists available templates" {
  run_wt templates
  [ "$status" -eq 0 ]
  [[ "$output" == *"laravel"* ]]
  [[ "$output" == *"node"* ]]
  [[ "$output" == *"minimal"* ]]
}

@test "wt templates: shows template descriptions" {
  run_wt templates
  [ "$status" -eq 0 ]
  [[ "$output" == *"Laravel full setup"* ]]
  [[ "$output" == *"Node.js only"* ]]
}

@test "wt templates <name>: shows detailed template info" {
  run_wt templates laravel
  [ "$status" -eq 0 ]
  [[ "$output" == *"laravel"* ]]
  [[ "$output" == *"Laravel full setup"* ]]
}

@test "wt templates: handles nonexistent template" {
  run_wt templates nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"Template"* ]]
}

# ============================================================================
# Flag parsing
# ============================================================================

@test "flag parsing: unknown flag rejected" {
  run_wt --unknown-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown flag"* ]]
}

@test "flag parsing: -t requires argument" {
  run_wt add testrepo feature/test -t
  [ "$status" -ne 0 ]
  [[ "$output" == *"Template name required"* ]] || [[ "$output" == *"-t"* ]]
}

@test "flag parsing: --template= requires value" {
  run_wt add testrepo feature/test --template=
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty"* ]]
}

# ============================================================================
# Validation - error cases
# ============================================================================

@test "validation: rejects path traversal in repo name" {
  run_wt ls "../etc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"path traversal"* ]] || [[ "$output" == *"Invalid"* ]]
}

@test "validation: rejects absolute path in repo name" {
  run_wt ls "/etc/passwd"
  [ "$status" -ne 0 ]
  [[ "$output" == *"absolute"* ]] || [[ "$output" == *"Invalid"* ]]
}

@test "validation: rejects path with double dots" {
  run_wt add testrepo "feature/../../../etc" --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"path traversal"* ]] || [[ "$output" == *"Invalid"* ]]
}

# ============================================================================
# Template validation (unit tests via test-helper validate_template_name)
# ============================================================================

@test "template validation: rejects path traversal" {
  run validate_template_name "../etc/passwd"
  [ "$status" -ne 0 ]
  [[ "$output" == *"path"* ]] || [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"not allowed"* ]]
}

@test "template validation: rejects slashes in template name" {
  run validate_template_name "path/to/template"
  [ "$status" -ne 0 ]
  [[ "$output" == *"path"* ]] || [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"not allowed"* ]]
}

@test "template validation: rejects special characters" {
  run validate_template_name 'test$(whoami)'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"only"* ]]
}

# ============================================================================
# wt doctor - System check
# ============================================================================

@test "wt doctor: runs and produces output" {
  run_wt doctor
  # doctor may return warnings (non-zero) but should produce output
  [[ "$output" == *"Checking"* ]] || [[ "$output" == *"System"* ]] || [[ "$output" == *"git"* ]]
}

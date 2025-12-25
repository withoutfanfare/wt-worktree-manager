#!/usr/bin/env bats
# url-generation.bats - Tests for url_for() and wt_path_for() functions
#
# Tests URL and path generation for worktrees

load '../test-helper'

setup() {
  setup_test_environment
  # Reset subdomain for each test
  unset WT_URL_SUBDOMAIN
}

teardown() {
  teardown_test_environment
}

# ============================================================================
# wt_path_for() tests
# ============================================================================

@test "wt_path_for: simple repo and branch" {
  result="$(wt_path_for "myapp" "main")"
  [ "$result" = "$HERD_ROOT/myapp--main" ]
}

@test "wt_path_for: feature branch with slash" {
  result="$(wt_path_for "myapp" "feature/login")"
  [ "$result" = "$HERD_ROOT/myapp--feature-login" ]
}

@test "wt_path_for: nested branch" {
  result="$(wt_path_for "myapp" "feature/user/auth")"
  [ "$result" = "$HERD_ROOT/myapp--feature-user-auth" ]
}

@test "wt_path_for: repo with dashes" {
  result="$(wt_path_for "my-app" "main")"
  [ "$result" = "$HERD_ROOT/my-app--main" ]
}

@test "wt_path_for: uses HERD_ROOT from environment" {
  export HERD_ROOT="/custom/path"
  result="$(wt_path_for "myapp" "main")"
  [ "$result" = "/custom/path/myapp--main" ]
}

@test "wt_path_for: double dash separator" {
  result="$(wt_path_for "myapp" "feature/test")"
  # Should have double dash between repo and slugified branch
  [[ "$result" == *"--"* ]]
}

# ============================================================================
# url_for() tests - without subdomain
# ============================================================================

@test "url_for: simple repo and branch" {
  result="$(url_for "myapp" "main")"
  [ "$result" = "https://myapp--main.test" ]
}

@test "url_for: feature branch with slash" {
  result="$(url_for "myapp" "feature/login")"
  [ "$result" = "https://myapp--feature-login.test" ]
}

@test "url_for: nested branch" {
  result="$(url_for "myapp" "feature/user/auth")"
  [ "$result" = "https://myapp--feature-user-auth.test" ]
}

@test "url_for: uses https" {
  result="$(url_for "myapp" "main")"
  [[ "$result" == "https://"* ]]
}

@test "url_for: ends with .test" {
  result="$(url_for "myapp" "main")"
  [[ "$result" == *".test" ]]
}

@test "url_for: repo with dashes preserved" {
  result="$(url_for "my-app" "main")"
  [ "$result" = "https://my-app--main.test" ]
}

# ============================================================================
# url_for() tests - with subdomain
# ============================================================================

@test "url_for: with subdomain prefix" {
  export WT_URL_SUBDOMAIN="api"
  result="$(url_for "myapp" "main")"
  [ "$result" = "https://api.myapp--main.test" ]
}

@test "url_for: subdomain with feature branch" {
  export WT_URL_SUBDOMAIN="api"
  result="$(url_for "myapp" "feature/login")"
  [ "$result" = "https://api.myapp--feature-login.test" ]
}

@test "url_for: empty subdomain produces no prefix" {
  export WT_URL_SUBDOMAIN=""
  result="$(url_for "myapp" "main")"
  [ "$result" = "https://myapp--main.test" ]
}

@test "url_for: subdomain appears before site name" {
  export WT_URL_SUBDOMAIN="admin"
  result="$(url_for "myapp" "main")"
  # Format: https://subdomain.site-name.test
  [[ "$result" == "https://admin."* ]]
}

# ============================================================================
# Path and URL consistency
# ============================================================================

@test "path and url use same slug" {
  repo="myapp"
  branch="feature/login"

  path="$(wt_path_for "$repo" "$branch")"
  url="$(url_for "$repo" "$branch")"

  # Extract site name from path (after last /)
  path_site="${path##*/}"

  # Extract site name from URL (between // and .test)
  url_site="${url#https://}"
  url_site="${url_site%.test}"

  # They should match (path uses directory, URL uses hostname)
  [ "$path_site" = "$url_site" ]
}

@test "path and url consistent for complex branch" {
  repo="scooda"
  branch="feature/dh/uat/build-test"

  path="$(wt_path_for "$repo" "$branch")"
  url="$(url_for "$repo" "$branch")"

  # Both should contain the same slugified pattern
  [[ "$path" == *"scooda--feature-dh-uat-build-test"* ]]
  [[ "$url" == *"scooda--feature-dh-uat-build-test"* ]]
}

# ============================================================================
# Edge cases
# ============================================================================

@test "wt_path_for: single char names" {
  result="$(wt_path_for "a" "b")"
  [ "$result" = "$HERD_ROOT/a--b" ]
}

@test "url_for: single char names" {
  result="$(url_for "a" "b")"
  [ "$result" = "https://a--b.test" ]
}

@test "wt_path_for: branch with dots" {
  result="$(wt_path_for "myapp" "release/v1.2.3")"
  [ "$result" = "$HERD_ROOT/myapp--release-v1.2.3" ]
}

@test "url_for: branch with dots" {
  result="$(url_for "myapp" "release/v1.2.3")"
  [ "$result" = "https://myapp--release-v1.2.3.test" ]
}

#!/bin/bash
echo "  [DEBUG] 02-configure-env.sh starting..."
# Configure .env with worktree-specific values
#
# Sets APP_URL and DB_DATABASE based on the worktree.
# Requires: .env file exists

if [[ ! -f "${WT_PATH}/.env" ]]; then
  exit 0
fi

cd "$WT_PATH" || exit 0

# Set APP_URL
if grep -q "^APP_URL=" .env 2>/dev/null; then
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|^APP_URL=.*|APP_URL=${WT_URL}|" .env
  else
    sed -i "s|^APP_URL=.*|APP_URL=${WT_URL}|" .env
  fi
  echo "  Set APP_URL=${WT_URL}"
fi

# Set DB_DATABASE
if grep -q "^DB_DATABASE=" .env 2>/dev/null; then
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|^DB_DATABASE=.*|DB_DATABASE=${WT_DB_NAME}|" .env
  else
    sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${WT_DB_NAME}|" .env
  fi
  echo "  Set DB_DATABASE=${WT_DB_NAME}"
fi

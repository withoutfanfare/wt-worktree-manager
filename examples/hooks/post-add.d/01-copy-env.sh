#!/bin/bash
echo "  [DEBUG] 01-copy-env.sh starting..."
# Copy .env.example to .env if it doesn't exist
#
# This hook creates a fresh .env file from the template.
# Repo-specific hooks can override this (e.g., to symlink instead).

if [[ -f "${WT_PATH}/.env.example" && ! -f "${WT_PATH}/.env" ]]; then
  cp "${WT_PATH}/.env.example" "${WT_PATH}/.env"
  echo "  Created .env from .env.example"
fi

#!/bin/bash
echo "  [DEBUG] 06-npm-install.sh starting..."
# Run npm install for Node.js projects
#
# Only runs if package.json exists.
# Skip by setting: WT_SKIP_NPM=true

if [[ "${WT_SKIP_NPM:-}" == "true" ]]; then
  echo "  Skipping npm install (WT_SKIP_NPM=true)"
  exit 0
fi

if [[ ! -f "${WT_PATH}/package.json" ]]; then
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "  npm not found - run manually: npm install"
  exit 0
fi

cd "$WT_PATH" || exit 0

echo "  Running npm install..."
if npm install --silent 2>/dev/null; then
  echo "  npm install complete"
else
  echo "  npm install failed - run manually: npm install"
fi

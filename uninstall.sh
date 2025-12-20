#!/bin/bash
set -e

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="${WT_INSTALL_DIR:-/usr/local/bin}"
COMPLETIONS_DIR="${WT_COMPLETIONS_DIR:-$HOME/.zsh/completions}"

echo ""
echo -e "${BLUE}Uninstalling wt...${NC}"
echo ""

# Remove main script
if [[ -f "$INSTALL_DIR/wt" ]]; then
  if [[ -w "$INSTALL_DIR/wt" ]]; then
    rm "$INSTALL_DIR/wt"
  else
    sudo rm "$INSTALL_DIR/wt"
  fi
  echo -e "  ${GREEN}✓${NC} Removed $INSTALL_DIR/wt"
else
  echo -e "  ${YELLOW}!${NC} $INSTALL_DIR/wt not found"
fi

# Remove completions
if [[ -f "$COMPLETIONS_DIR/_wt" ]]; then
  rm "$COMPLETIONS_DIR/_wt"
  echo -e "  ${GREEN}✓${NC} Removed $COMPLETIONS_DIR/_wt"
else
  echo -e "  ${YELLOW}!${NC} $COMPLETIONS_DIR/_wt not found"
fi

echo ""
echo -e "${GREEN}Uninstall complete!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Your config file (~/.wtrc) was preserved."
echo "      Delete it manually if you no longer need it:"
echo ""
echo -e "      ${YELLOW}rm ~/.wtrc${NC}"
echo ""
echo "      Your worktrees and bare repos in ~/Herd are also preserved."
echo ""

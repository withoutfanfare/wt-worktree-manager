#!/bin/bash
set -e

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

# Defaults - should match install.sh
INSTALL_DIR="${WT_INSTALL_DIR:-/usr/local/bin}"

# Auto-detect completions directory (same logic as install.sh)
detect_completions_dir() {
  if [[ -d "/opt/homebrew/share/zsh/site-functions" ]]; then
    echo "/opt/homebrew/share/zsh/site-functions"
  elif [[ -d "/usr/local/share/zsh/site-functions" ]]; then
    echo "/usr/local/share/zsh/site-functions"
  else
    echo "$HOME/.zsh/completions"
  fi
}

COMPLETIONS_DIR="${WT_COMPLETIONS_DIR:-$(detect_completions_dir)}"

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Uninstalling ${GREEN}wt${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Remove main script (file or symlink)
if [[ -e "$INSTALL_DIR/wt" || -L "$INSTALL_DIR/wt" ]]; then
  if [[ -w "$INSTALL_DIR" ]]; then
    rm -f "$INSTALL_DIR/wt"
  else
    sudo rm -f "$INSTALL_DIR/wt"
  fi
  echo -e "  ${GREEN}✓${NC} Removed $INSTALL_DIR/wt"
else
  echo -e "  ${DIM}!${NC} $INSTALL_DIR/wt not found"
fi

# Remove completions (file or symlink)
if [[ -e "$COMPLETIONS_DIR/_wt" || -L "$COMPLETIONS_DIR/_wt" ]]; then
  if [[ -w "$COMPLETIONS_DIR" ]]; then
    rm -f "$COMPLETIONS_DIR/_wt"
  else
    sudo rm -f "$COMPLETIONS_DIR/_wt"
  fi
  echo -e "  ${GREEN}✓${NC} Removed $COMPLETIONS_DIR/_wt"
else
  echo -e "  ${DIM}!${NC} $COMPLETIONS_DIR/_wt not found"
fi

# Also check common alternative locations
for alt_dir in "$HOME/bin" "$HOME/.local/bin"; do
  if [[ -e "$alt_dir/wt" || -L "$alt_dir/wt" ]]; then
    rm -f "$alt_dir/wt"
    echo -e "  ${GREEN}✓${NC} Removed $alt_dir/wt"
  fi
done

for alt_comp in "$HOME/.zsh/completions/_wt" "/opt/homebrew/share/zsh/site-functions/_wt" "/usr/local/share/zsh/site-functions/_wt"; do
  if [[ "$alt_comp" != "$COMPLETIONS_DIR/_wt" ]] && [[ -e "$alt_comp" || -L "$alt_comp" ]]; then
    if [[ -w "$(dirname "$alt_comp")" ]]; then
      rm -f "$alt_comp"
    else
      sudo rm -f "$alt_comp"
    fi
    echo -e "  ${GREEN}✓${NC} Removed $alt_comp"
  fi
done

echo ""
echo -e "${GREEN}Uninstall complete!${NC}"
echo ""
echo -e "${YELLOW}Preserved:${NC}"
echo -e "  ${DIM}~/.wtrc${NC} - Your configuration file"
echo -e "  ${DIM}~/.wt/${NC} - Your hooks directory"
echo -e "  ${DIM}~/Herd/*.git${NC} - Your bare repositories"
echo -e "  ${DIM}~/Herd/*${NC} - Your worktrees"
echo ""
echo -e "To remove all user data:"
echo -e "  ${YELLOW}rm ~/.wtrc${NC}"
echo -e "  ${YELLOW}rm -rf ~/.wt${NC}"
echo ""

#!/bin/bash
set -e

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# Defaults
INSTALL_DIR="${WT_INSTALL_DIR:-/usr/local/bin}"
COMPLETIONS_DIR="${WT_COMPLETIONS_DIR:-$HOME/.zsh/completions}"

print_header() {
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC}    ${GREEN}wt${NC} - Git Worktree Manager          ${BLUE}║${NC}"
  echo -e "${BLUE}║${NC}    for Laravel Herd                    ${BLUE}║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
  echo ""
}

check_requirements() {
  local missing=()

  echo -e "${BLUE}Checking requirements...${NC}"

  # Check for zsh
  if ! command -v zsh &> /dev/null; then
    missing+=("zsh")
  else
    echo -e "  ${GREEN}✓${NC} zsh"
  fi

  # Check for git
  if ! command -v git &> /dev/null; then
    missing+=("git")
  else
    echo -e "  ${GREEN}✓${NC} git"
  fi

  # Check for Laravel Herd
  if ! command -v herd &> /dev/null; then
    echo -e "  ${YELLOW}!${NC} herd (Laravel Herd not found - some features will be limited)"
  else
    echo -e "  ${GREEN}✓${NC} herd"
  fi

  # Check for composer
  if ! command -v composer &> /dev/null; then
    echo -e "  ${YELLOW}!${NC} composer (optional, needed for Laravel projects)"
  else
    echo -e "  ${GREEN}✓${NC} composer"
  fi

  # Check for fzf
  if ! command -v fzf &> /dev/null; then
    echo -e "  ${YELLOW}!${NC} fzf (optional, enables interactive selection)"
  else
    echo -e "  ${GREEN}✓${NC} fzf"
  fi

  # Check for mysql
  if ! command -v mysql &> /dev/null; then
    echo -e "  ${YELLOW}!${NC} mysql (optional, enables database management)"
  else
    echo -e "  ${GREEN}✓${NC} mysql"
  fi

  echo ""

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}Missing required dependencies: ${missing[*]}${NC}"
    echo "Please install them and try again."
    exit 1
  fi
}

install_script() {
  echo -e "${BLUE}Installing wt...${NC}"

  # Create install directory if needed
  if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "  Creating $INSTALL_DIR..."
    sudo mkdir -p "$INSTALL_DIR"
  fi

  # Copy the main script
  if [[ -w "$INSTALL_DIR" ]]; then
    cp wt "$INSTALL_DIR/wt"
    chmod +x "$INSTALL_DIR/wt"
  else
    sudo cp wt "$INSTALL_DIR/wt"
    sudo chmod +x "$INSTALL_DIR/wt"
  fi
  echo -e "  ${GREEN}✓${NC} Installed wt to $INSTALL_DIR/wt"
}

install_completions() {
  echo -e "${BLUE}Installing zsh completions...${NC}"

  # Create completions directory
  mkdir -p "$COMPLETIONS_DIR"

  # Copy completion script
  cp _wt "$COMPLETIONS_DIR/_wt"
  echo -e "  ${GREEN}✓${NC} Installed completions to $COMPLETIONS_DIR/_wt"
}

create_config() {
  local config_file="$HOME/.wtrc"

  if [[ -f "$config_file" ]]; then
    echo -e "${YELLOW}Config file already exists at $config_file${NC}"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      return
    fi
  fi

  echo -e "${BLUE}Creating config file...${NC}"

  # Detect Herd root
  local herd_root="$HOME/Herd"
  if [[ -d "$HOME/Herd" ]]; then
    herd_root="$HOME/Herd"
  elif [[ -d "$HOME/Sites" ]]; then
    herd_root="$HOME/Sites"
  fi

  cat > "$config_file" << EOF
# wt configuration file
# See: https://github.com/YOUR_USERNAME/wt-worktree-manager

# Where your Herd/Valet sites live
HERD_ROOT=$herd_root

# Default base branch for new worktrees
DEFAULT_BASE=origin/staging

# Editor to open with 'wt code'
DEFAULT_EDITOR=cursor

# Database connection
DB_HOST=127.0.0.1
DB_USER=root
DB_PASSWORD=
DB_CREATE=true

# Database backup on removal
DB_BACKUP=true
DB_BACKUP_DIR="\$HOME/Code/Project Support/Worktree/Database/Backup"

# Protected branches (require -f to remove)
PROTECTED_BRANCHES="staging main master"
EOF

  echo -e "  ${GREEN}✓${NC} Created config at $config_file"
}

print_next_steps() {
  echo ""
  echo -e "${GREEN}Installation complete!${NC}"
  echo ""
  echo -e "${BLUE}Next steps:${NC}"
  echo ""
  echo "1. Add completions to your ~/.zshrc (if not already there):"
  echo ""
  echo -e "   ${YELLOW}fpath=(~/.zsh/completions \$fpath)${NC}"
  echo -e "   ${YELLOW}autoload -Uz compinit && compinit${NC}"
  echo ""
  echo "2. Reload your shell:"
  echo ""
  echo -e "   ${YELLOW}source ~/.zshrc${NC}"
  echo ""
  echo "3. Edit your config file:"
  echo ""
  echo -e "   ${YELLOW}$EDITOR ~/.wtrc${NC}"
  echo ""
  echo "4. Verify installation:"
  echo ""
  echo -e "   ${YELLOW}wt --version${NC}"
  echo -e "   ${YELLOW}wt doctor${NC}"
  echo ""
  echo -e "${BLUE}Quick start:${NC}"
  echo ""
  echo -e "   ${YELLOW}wt clone git@github.com:your-org/your-app.git${NC}"
  echo -e "   ${YELLOW}wt add your-app feature/my-feature${NC}"
  echo -e "   ${YELLOW}cd \"\$(wt switch your-app)\"${NC}"
  echo ""
}

# Main
print_header
check_requirements
install_script
install_completions
create_config
print_next_steps

#!/bin/bash

# Script to backup Homebrew packages to a Brewfile
# This script creates a Brewfile in ~/.config/brew/ using brew bundle dump
# The Brewfile will be managed by chezmoi dot files manager

set -euo pipefail

# Color definitions
RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

# Define the directory and file paths
BREW_CONFIG_DIR="$HOME/.config/brew"
BREWFILE="$BREW_CONFIG_DIR/Brewfile"

# Create the directory if it doesn't exist
mkdir -p "$BREW_CONFIG_DIR"

# Create/overwrite the Brewfile using brew bundle dump
echo -e "${CYAN}⏳ Creating Brewfile backup...${RESET}"
brew bundle dump --file "$BREWFILE" --force --debug --no-vscode

echo -e "${GREEN}✅ Brewfile backup completed successfully!${RESET}"
echo -e "${YELLOW}ℹ️ Brewfile backup location: $BREWFILE${RESET}"


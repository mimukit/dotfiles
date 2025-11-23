#!/bin/bash

# Script to restore Homebrew packages from a Brewfile
# This script installs all packages listed in the Brewfile created by brew_apps_backup.sh
# The Brewfile is expected to be located at ~/.config/brew/Brewfile

set -euo pipefail

# Color definitions
RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

# Define the directory and file paths
BREW_CONFIG_DIR="$HOME/.config/brew"
BREWFILE="$BREW_CONFIG_DIR/Brewfile"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Safety check 1: Verify Homebrew is installed
echo -e "${CYAN}🔍 Checking if Homebrew is installed...${RESET}"
if ! command_exists brew; then
    echo -e "${RED}❌ Error: Homebrew is not installed.${RESET}"
    echo -e "${YELLOW}ℹ️  Please install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${RESET}"
    exit 1
fi
echo -e "${GREEN}✅ Homebrew is installed${RESET}"

# Safety check 2: Verify brew bundle command is available
echo -e "${CYAN}🔍 Checking if brew bundle command is available...${RESET}"
if ! brew bundle --help >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: brew bundle command is not available.${RESET}"
    echo -e "${YELLOW}ℹ️  The bundle command should be included with Homebrew. Try updating Homebrew: brew update${RESET}"
    exit 1
fi
echo -e "${GREEN}✅ brew bundle command is available${RESET}"

# Safety check 3: Verify Brewfile exists
echo -e "${CYAN}🔍 Checking if Brewfile exists...${RESET}"
if [ ! -f "$BREWFILE" ]; then
    echo -e "${RED}❌ Error: Brewfile not found at $BREWFILE${RESET}"
    echo -e "${YELLOW}ℹ️  Please run brew_apps_backup.sh first to create a Brewfile, or ensure the Brewfile exists at the expected location.${RESET}"
    exit 1
fi
echo -e "${GREEN}✅ Brewfile found at $BREWFILE${RESET}"

# Safety check 4: Verify Brewfile is not empty
if [ ! -s "$BREWFILE" ]; then
    echo -e "${RED}❌ Error: Brewfile is empty.${RESET}"
    echo -e "${YELLOW}ℹ️  The Brewfile exists but contains no packages. Please run brew_apps_backup.sh to create a valid Brewfile.${RESET}"
    exit 1
fi
echo -e "${GREEN}✅ Brewfile is not empty${RESET}"

# All safety checks passed, proceed with restoration
echo ""
echo -e "${CYAN}⏳ Starting restoration of Homebrew packages from Brewfile...${RESET}"
echo -e "${YELLOW}ℹ️  This may take a while depending on the number of packages...${RESET}"
echo ""

# Install all packages from the Brewfile
if brew bundle install --file "$BREWFILE"; then
    echo ""
    echo -e "${GREEN}✅ All packages from Brewfile have been installed successfully!${RESET}"
else
    echo ""
    echo -e "${RED}❌ Error: Some packages failed to install.${RESET}"
    echo -e "${YELLOW}ℹ️  Please review the output above for details.${RESET}"
    exit 1
fi


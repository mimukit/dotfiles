#!/bin/bash

# Script to cleanup Homebrew packages and casks not present in Brewfile
# This script uninstalls all packages/casks that are installed but not listed
# in the Brewfile created by brew_apps_backup.sh
# The Brewfile is expected to be located at ~/.config/brew/Brewfile

set -euo pipefail

# Color definitions
RESET='\033[0m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'

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

# Safety check 2: Verify Brewfile exists
echo -e "${CYAN}🔍 Checking if Brewfile exists...${RESET}"
if [ ! -f "$BREWFILE" ]; then
    echo -e "${RED}❌ Error: Brewfile not found at $BREWFILE${RESET}"
    echo -e "${YELLOW}ℹ️  Please run brew_apps_backup.sh first to create a Brewfile.${RESET}"
    exit 1
fi
echo -e "${GREEN}✅ Brewfile found at $BREWFILE${RESET}"

# Safety check 3: Verify Brewfile is not empty
if [ ! -s "$BREWFILE" ]; then
    echo -e "${RED}❌ Error: Brewfile is empty.${RESET}"
    echo -e "${YELLOW}ℹ️  The Brewfile exists but contains no packages. Please run brew_apps_backup.sh to create a valid Brewfile.${RESET}"
    exit 1
fi
echo -e "${GREEN}✅ Brewfile is not empty${RESET}"

# Function to extract packages from Brewfile
extract_brewfile_packages() {
    local type=$1  # "brew" or "cask"
    grep -E "^${type} " "$BREWFILE" | sed "s/^${type} \"//" | sed "s/\"$//" | sort
}

# Extract packages and casks from Brewfile
echo ""
echo -e "${CYAN}📋 Extracting packages from Brewfile...${RESET}"
BREWFILE_FORMULAE=$(extract_brewfile_packages "brew")
BREWFILE_CASKS=$(extract_brewfile_packages "cask")

BREWFILE_FORMULAE_COUNT=$(echo "$BREWFILE_FORMULAE" | grep -c . || echo "0")
BREWFILE_CASKS_COUNT=$(echo "$BREWFILE_CASKS" | grep -c . || echo "0")

echo -e "${GREEN}✅ Found ${BREWFILE_FORMULAE_COUNT} formulae and ${BREWFILE_CASKS_COUNT} casks in Brewfile${RESET}"

# Get currently installed packages and casks
echo ""
echo -e "${CYAN}📦 Getting list of currently installed packages...${RESET}"
INSTALLED_FORMULAE=$(brew list --formula 2>/dev/null | sort || echo "")
INSTALLED_CASKS=$(brew list --cask 2>/dev/null | sort || echo "")

INSTALLED_FORMULAE_COUNT=$(echo "$INSTALLED_FORMULAE" | grep -c . || echo "0")
INSTALLED_CASKS_COUNT=$(echo "$INSTALLED_CASKS" | grep -c . || echo "0")

echo -e "${GREEN}✅ Found ${INSTALLED_FORMULAE_COUNT} installed formulae and ${INSTALLED_CASKS_COUNT} installed casks${RESET}"

# Find packages/casks that are installed but not in Brewfile
echo ""
echo -e "${CYAN}🔍 Comparing installed packages with Brewfile...${RESET}"

# Use temporary files for comm (more portable than process substitution)
TMP_DIR=$(mktemp -d)
# Single quotes on purpose: $TMP_DIR must expand when the trap fires, not when
# it is installed. Double quotes would bake in whatever the variable held at
# install time, so a later reassignment would leave the real directory behind.
# shellcheck disable=SC2064  # the expansion is deferred deliberately
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

echo "$INSTALLED_FORMULAE" > "$TMP_DIR/installed_formulae.txt"
echo "$BREWFILE_FORMULAE" > "$TMP_DIR/brewfile_formulae.txt"
echo "$INSTALLED_CASKS" > "$TMP_DIR/installed_casks.txt"
echo "$BREWFILE_CASKS" > "$TMP_DIR/brewfile_casks.txt"

# Use comm to find differences (comm -23 shows lines only in first file)
EXTRA_FORMULAE=$(comm -23 "$TMP_DIR/installed_formulae.txt" "$TMP_DIR/brewfile_formulae.txt" 2>/dev/null || echo "")
EXTRA_CASKS=$(comm -23 "$TMP_DIR/installed_casks.txt" "$TMP_DIR/brewfile_casks.txt" 2>/dev/null || echo "")

EXTRA_FORMULAE_COUNT=$(echo "$EXTRA_FORMULAE" | grep -c . || echo "0")
EXTRA_CASKS_COUNT=$(echo "$EXTRA_CASKS" | grep -c . || echo "0")

if [ "$EXTRA_FORMULAE_COUNT" -eq 0 ] && [ "$EXTRA_CASKS_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ No extra packages found. All installed packages are in the Brewfile.${RESET}"
    echo ""
    echo -e "${CYAN}🧹 Running cleanup commands anyway...${RESET}"
    
    # Run cleanup commands
    echo -e "${CYAN}⏳ Running brew cleanup...${RESET}"
    brew cleanup --prune=all 2>/dev/null || brew cleanup 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup completed${RESET}"
    
    echo -e "${CYAN}⏳ Running brew autoremove...${RESET}"
    brew autoremove 2>/dev/null || true
    echo -e "${GREEN}✅ Autoremove completed${RESET}"
    
    echo ""
    echo -e "${GREEN}✅ All cleanup operations completed successfully!${RESET}"
    exit 0
fi

# Selection menu for cleanup type
CLEANUP_FORMULAE=false
CLEANUP_CASKS=false

echo ""
echo -e "${CYAN}📋 Select cleanup type:${RESET}"
echo ""
if [ "$EXTRA_FORMULAE_COUNT" -gt 0 ] && [ "$EXTRA_CASKS_COUNT" -gt 0 ]; then
    echo -e "  ${YELLOW}1)${RESET} Formulae only (${EXTRA_FORMULAE_COUNT} packages)"
    echo -e "  ${YELLOW}2)${RESET} Casks only (${EXTRA_CASKS_COUNT} packages)"
    echo -e "  ${YELLOW}3)${RESET} Both formulae and casks (${EXTRA_FORMULAE_COUNT} + ${EXTRA_CASKS_COUNT} packages)"
    echo ""
    while true; do
        read -p "$(echo -e ${CYAN}Enter your choice [1-3]: ${RESET})" choice
        case $choice in
            1)
                CLEANUP_FORMULAE=true
                break
                ;;
            2)
                CLEANUP_CASKS=true
                break
                ;;
            3)
                CLEANUP_FORMULAE=true
                CLEANUP_CASKS=true
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 1, 2, or 3.${RESET}"
                ;;
        esac
    done
elif [ "$EXTRA_FORMULAE_COUNT" -gt 0 ]; then
    echo -e "  ${YELLOW}1)${RESET} Formulae only (${EXTRA_FORMULAE_COUNT} packages)"
    echo ""
    while true; do
        read -p "$(echo -e ${CYAN}Enter your choice [1]: ${RESET})" choice
        case $choice in
            1)
                CLEANUP_FORMULAE=true
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 1.${RESET}"
                ;;
        esac
    done
elif [ "$EXTRA_CASKS_COUNT" -gt 0 ]; then
    echo -e "  ${YELLOW}1)${RESET} Casks only (${EXTRA_CASKS_COUNT} packages)"
    echo ""
    while true; do
        read -p "$(echo -e ${CYAN}Enter your choice [1]: ${RESET})" choice
        case $choice in
            1)
                CLEANUP_CASKS=true
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 1.${RESET}"
                ;;
        esac
    done
fi

# Display selected packages to be removed
echo ""
if [ "$CLEANUP_FORMULAE" = true ] && [ "$EXTRA_FORMULAE_COUNT" -gt 0 ]; then
    echo -e "${MAGENTA}📋 Extra formulae to be removed (${EXTRA_FORMULAE_COUNT}):${RESET}"
    echo "$EXTRA_FORMULAE" | while read -r formula; do
        echo -e "  ${YELLOW}•${RESET} $formula"
    done
fi

if [ "$CLEANUP_CASKS" = true ] && [ "$EXTRA_CASKS_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${MAGENTA}📋 Extra casks to be removed (${EXTRA_CASKS_COUNT}):${RESET}"
    echo "$EXTRA_CASKS" | while read -r cask; do
        echo -e "  ${YELLOW}•${RESET} $cask"
    done
fi

# Confirmation prompt
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will uninstall the packages listed above.${RESET}"
read -p "$(echo -e ${CYAN}Continue? [y/N]: ${RESET})" -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}ℹ️  Cleanup cancelled by user.${RESET}"
    exit 0
fi

# Uninstall extra formulae
if [ "$CLEANUP_FORMULAE" = true ] && [ "$EXTRA_FORMULAE_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${CYAN}🗑️  Uninstalling extra formulae...${RESET}"
    echo "$EXTRA_FORMULAE" | while read -r formula; do
        if [ -n "$formula" ]; then
            echo -e "${CYAN}  Removing: ${YELLOW}$formula${RESET}"
            brew uninstall --ignore-dependencies "$formula" 2>/dev/null || brew uninstall "$formula" 2>/dev/null || true
        fi
    done
    echo -e "${GREEN}✅ Extra formulae uninstalled${RESET}"
fi

# Uninstall extra casks
if [ "$CLEANUP_CASKS" = true ] && [ "$EXTRA_CASKS_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${CYAN}🗑️  Uninstalling extra casks...${RESET}"
    echo "$EXTRA_CASKS" | while read -r cask; do
        if [ -n "$cask" ]; then
            echo -e "${CYAN}  Removing: ${YELLOW}$cask${RESET}"
            brew uninstall --cask --ignore-dependencies "$cask" 2>/dev/null || brew uninstall --cask "$cask" 2>/dev/null || true
        fi
    done
    echo -e "${GREEN}✅ Extra casks uninstalled${RESET}"
fi

# Run cleanup commands
echo ""
echo -e "${CYAN}🧹 Running cleanup commands...${RESET}"

echo -e "${CYAN}⏳ Running brew cleanup (removing old versions and cache)...${RESET}"
brew cleanup --prune=all 2>/dev/null || brew cleanup 2>/dev/null || true
echo -e "${GREEN}✅ Cleanup completed${RESET}"

echo -e "${CYAN}⏳ Running brew autoremove (removing unused dependencies)...${RESET}"
brew autoremove 2>/dev/null || true
echo -e "${GREEN}✅ Autoremove completed${RESET}"

echo ""
echo -e "${GREEN}✅ All cleanup operations completed successfully!${RESET}"

# Display summary based on what was actually cleaned
REMOVED_FORMULAE_COUNT=0
REMOVED_CASKS_COUNT=0
if [ "$CLEANUP_FORMULAE" = true ] && [ "$EXTRA_FORMULAE_COUNT" -gt 0 ]; then
    REMOVED_FORMULAE_COUNT=$EXTRA_FORMULAE_COUNT
fi
if [ "$CLEANUP_CASKS" = true ] && [ "$EXTRA_CASKS_COUNT" -gt 0 ]; then
    REMOVED_CASKS_COUNT=$EXTRA_CASKS_COUNT
fi

if [ "$REMOVED_FORMULAE_COUNT" -gt 0 ] && [ "$REMOVED_CASKS_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}ℹ️  Removed ${REMOVED_FORMULAE_COUNT} formulae and ${REMOVED_CASKS_COUNT} casks not in Brewfile${RESET}"
elif [ "$REMOVED_FORMULAE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}ℹ️  Removed ${REMOVED_FORMULAE_COUNT} formulae not in Brewfile${RESET}"
elif [ "$REMOVED_CASKS_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}ℹ️  Removed ${REMOVED_CASKS_COUNT} casks not in Brewfile${RESET}"
fi


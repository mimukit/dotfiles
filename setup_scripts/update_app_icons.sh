#!/bin/zsh

# Define colored output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
  echo -e "${RED}[ERROR] Homebrew is not installed. Please install Homebrew first from https://brew.sh.${NC}"
  exit 1
fi

# Check if fileicon is installed; if not, install it
if ! command -v fileicon &>/dev/null; then
  echo -e "${YELLOW}[INFO] 'fileicon' not found. Installing it using Homebrew...${NC}"
  brew install fileicon

  # Re-check if installation was successful
  if ! command -v fileicon &>/dev/null; then
    echo -e "${RED}[ERROR] Failed to install 'fileicon'. Please try installing manually.${NC}"
    exit 1
  fi

  echo -e "${GREEN}[SUCCESS] 'fileicon' installed successfully.${NC}"
fi

# Array of app/icon path pairs (format: "APP_PATH|ICON_PATH")
declare -a APP_ICON_PAIRS=(
  "/Applications/1Password.app|${HOME}/.config/icons/1password.icns"
  "/Applications/Discord.app|${HOME}/.config/icons/discord.icns"
  "/Applications/Firefox.app|${HOME}/.config/icons/firefox.icns"
  "/Applications/Ghostty.app|${HOME}/.config/icons/terminal.icns"
  "/Applications/Google Chrome.app|${HOME}/.config/icons/chrome.icns"
  "/Applications/iTerm.app|${HOME}/.config/icons/terminal_7.icns"
  "/Applications/Notion.app|${HOME}/.config/icons/notion.icns"
  "/Applications/Obsidian.app|${HOME}/.config/icons/obsidian.icns"
  "/Applications/Slack.app|${HOME}/.config/icons/slack.icns"
  "/Applications/Telegram Desktop.app|${HOME}/.config/icons/telegram.icns"
  "/Applications/TickTick.app|${HOME}/.config/icons/ticktick.icns"
  "/Applications/VLC.app|${HOME}/.config/icons/vlc.icns"
  "/Applications/Visual Studio Code.app|${HOME}/.config/icons/vscode.icns"
)

# Loop through the app/icon pairs
for pair in "${APP_ICON_PAIRS[@]}"; do
  APP_PATH="${pair%%|*}"
  ICON_PATH="${pair##*|}"

  echo -e "\n${YELLOW}Processing: ${APP_PATH}${NC}"

  if [[ ! -e "$APP_PATH" ]]; then
    echo -e "${RED}[ERROR] Application not found: $APP_PATH${NC}"
    continue
  fi

  if [[ ! -f "$ICON_PATH" ]]; then
    echo -e "${RED}[ERROR] Icon file not found: $ICON_PATH${NC}"
    continue
  fi

  if fileicon set "$APP_PATH" "$ICON_PATH"; then
    touch "$APP_PATH"
    echo -e "${GREEN}[SUCCESS] Icon updated for: $APP_PATH${NC}"
  else
    echo -e "${RED}[FAILED] Could not update icon for: $APP_PATH${NC}"
  fi
done

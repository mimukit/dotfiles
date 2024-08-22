#!/bin/bash

# Colors for echo
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Update and upgrade the system
echo -e "${GREEN}Updating and upgrading the system...${NC}"
sudo apt update && sudo apt upgrade -y
if [ $? -eq 0 ]; then
  echo -e "${GREEN}System updated and upgraded successfully.${NC}"
else
  echo -e "${RED}Failed to update and upgrade the system.${NC}"
  exit 1
fi

# Install necessary packages
echo -e "${GREEN}Installing required packages...${NC}"
sudo apt install -y software-properties-common build-essential curl zsh tmux git eza bat btop neovim unzip ripgrep fontconfig
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Packages installed successfully.${NC}"
else
  echo -e "${RED}Failed to install packages.${NC}"
  exit 1
fi

# Clone dotfiles repo
if [ ! -d "$HOME/dotfiles" ]; then
  echo -e "${GREEN}Cloning dotfiles repository...${NC}"
  git clone https://github.com/mimukit/dotfiles.git "$HOME/dotfiles"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}dotfiles repository cloned successfully.${NC}"
  else
    echo -e "${RED}Failed to clone dotfiles repository.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}dotfiles repository already exists. Skipping clone.${NC}"
fi

# Replace .zshrc with the one from dotfiles
if [ -f "$HOME/dotfiles/dot_zshrc" ]; then
  echo -e "${GREEN}Replacing .zshrc with custom configuration...${NC}"
  rm -f "$HOME/.zshrc"
  cp "$HOME/dotfiles/dot_zshrc" "$HOME/.zshrc"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}.zshrc replaced successfully.${NC}"
  else
    echo -e "${RED}Failed to replace .zshrc.${NC}"
    exit 1
  fi
else
  echo -e "${RED}dot_zshrc not found in dotfiles repository. Skipping.${NC}"
fi

# Clone tmux plugin manager
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo -e "${GREEN}Cloning tmux plugin manager...${NC}"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}tmux plugin manager cloned successfully.${NC}"
  else
    echo -e "${RED}Failed to clone tmux plugin manager.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}tmux plugin manager already exists. Skipping clone.${NC}"
fi

# Install fzf
if [ ! -d "$HOME/.fzf" ]; then
  echo -e "${GREEN}Cloning and installing fzf...${NC}"
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}fzf installed successfully.${NC}"
  else
    echo -e "${RED}Failed to install fzf.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}fzf already installed. Skipping clone and installation.${NC}"
fi

# Install fnm
if ! command -v fnm &>/dev/null; then
  echo -e "${GREEN}Installing fnm...${NC}"
  curl -fsSL https://fnm.vercel.app/install | bash
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}fnm installed successfully.${NC}"
  else
    echo -e "${RED}Failed to install fnm.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}fnm already installed. Skipping installation.${NC}"
fi

# Install the latest LTS version of Node.js using fnm
if command -v fnm &>/dev/null; then
  echo -e "${GREEN}Installing the latest LTS version of Node.js...${NC}"
  fnm install --lts
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Node.js LTS installed successfully.${NC}"
  else
    echo -e "${RED}Failed to install Node.js LTS.${NC}"
    exit 1
  fi
else
  echo -e "${RED}fnm not found. Cannot install Node.js LTS.${NC}"
  exit 1
fi

# Copy Neovim and tmux configurations
if [ -d "$HOME/dotfiles/dot_config/nvim" ]; then
  echo -e "${GREEN}Copying Neovim configuration...${NC}"
  mkdir -p "$HOME/.config/nvim"
  cp -r "$HOME/dotfiles/dot_config/nvim/" "$HOME/.config/nvim"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Neovim configuration copied successfully.${NC}"
  else
    echo -e "${RED}Failed to copy Neovim configuration.${NC}"
    exit 1
  fi
else
  echo -e "${RED}Neovim configuration not found in dotfiles repository. Skipping.${NC}"
fi

if [ -d "$HOME/dotfiles/dot_config/tmux" ]; then
  echo -e "${GREEN}Copying tmux configuration...${NC}"
  mkdir -p "$HOME/.config/tmux"
  cp -r "$HOME/dotfiles/dot_config/tmux/" "$HOME/.config/tmux"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}tmux configuration copied successfully.${NC}"
  else
    echo -e "${RED}Failed to copy tmux configuration.${NC}"
    exit 1
  fi
else
  echo -e "${RED}tmux configuration not found in dotfiles repository. Skipping.${NC}"
fi

echo -e "${GREEN}All tasks completed successfully.${NC}"


#!/bin/bash

# Colors for echo
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if sudo is available
if command -v sudo &>/dev/null; then
  SUDO="sudo"
else
  SUDO=""
fi

# Update and upgrade the system
echo -e "${GREEN}\n🚀 Updating and upgrading the system...${NC}"

$SUDO apt update && $SUDO apt upgrade -y

if [ $? -eq 0 ]; then
  echo -e "${GREEN}\n✅ System updated and upgraded successfully.${NC}"
else
  echo -e "${RED}\n❌ Failed to update and upgrade the system.${NC}"
  exit 1
fi

# Install necessary packages
echo -e "${GREEN}\n🚀 Installing required packages...${NC}"

$SUDO apt install -y \
  software-properties-common \
  build-essential \
  bat \
  btop \
  curl \
  eza \
  git \
  neovim \
  ripgrep \
  tmux \
  tree \
  unzip \
  zsh

if [ $? -eq 0 ]; then
  echo -e "${GREEN}\n✅ Packages installed successfully.${NC}"
else
  echo -e "${RED}\n❌ Failed to install packages.${NC}"
  exit 1
fi

# Clone dotfiles repo
if [ ! -d "$HOME/dotfiles" ]; then
  echo -e "${GREEN}\n🚀 Cloning dotfiles repository...${NC}"

  git clone https://github.com/mimukit/dotfiles.git "$HOME/dotfiles"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}\n✅ Dotfiles repository cloned successfully.${NC}"
  else
    echo -e "${RED}\n❌ Failed to clone dotfiles repository.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}\n⚠️  Dotfiles repository already exists. Skipping clone.${NC}"
fi

# Replace .zshrc with the one from dotfiles
if [ -f "$HOME/dotfiles/dot_zshrc" ]; then
  echo -e "${GREEN}\n🚀 Replacing .zshrc with custom configuration...${NC}"

  rm -f "$HOME/.zshrc"
  cp "$HOME/dotfiles/dot_zshrc" "$HOME/.zshrc"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}\n✅ .zshrc replaced successfully. Restarting zsh to install plugins...${NC}"
    exec zsh # Restart zsh to install plugins via zinit
  else
    echo -e "${RED}\n❌ Failed to replace .zshrc.${NC}"
    exit 1
  fi
else
  echo -e "${RED}\n⚠️  dot_zshrc not found in dotfiles repository. Please fix.${NC}"
  exit 1
fi

# Replace .tmux.conf with the one from dotfiles
if [ -d "$HOME/dotfiles/dot_config/tmux" ]; then
  echo -e "${GREEN}\n🚀 Copying tmux configuration...${NC}"

  mkdir -p "$HOME/.config/tmux"
  cp -r "$HOME/dotfiles/dot_config/tmux/" "$HOME/.config/tmux/"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}\n✅ Tmux configuration copied successfully.${NC}"
  else
    echo -e "${RED}\n❌ Failed to copy tmux configuration.${NC}"
    exit 1
  fi
else
  echo -e "${RED}\n⚠️  Tmux configuration not found in dotfiles repository. Please fix.${NC}"
  exit 1
fi

# Clone tmux plugin manager
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo -e "${GREEN}\n🚀 Cloning tmux plugin manager...${NC}"

  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

  # Start Tmux and install plugins
  tmux start-server
  tmux new-session -d
  ~/.tmux/plugins/tpm/bin/install_plugins
  tmux kill-server

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}\n✅ Tmux plugin manager cloned successfully.${NC}"
  else
    echo -e "${RED}\n❌ Failed to clone tmux plugin manager.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}\n⚠️  Tmux plugin manager already exists. Skipping clone.${NC}"
fi

# Install fzf
if [ ! -d "$HOME/.fzf" ]; then
  echo -e "${GREEN}\n🚀 Cloning and installing fzf...${NC}"

  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}\n✅ fzf installed successfully.${NC}"
  else
    echo -e "${RED}\n❌ Failed to install fzf.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}\n⚠️  fzf already installed. Skipping clone and installation.${NC}"
fi

# Install Node.js using NVM as an alternative to FNM
if ! command -v nvm &>/dev/null; then
  echo -e "${GREEN}\n🚀 Installing NVM (Node Version Manager)...${NC}"

  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
  source ~/.bashrc # Source .bashrc to make nvm command available

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}\n✅ NVM installed successfully.${NC}"

    nvm install --lts

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}\n✅ Node.js LTS installed successfully using NVM.${NC}"
    else
      echo -e "${RED}\n❌ Failed to install Node.js LTS.${NC}"
      exit 1
    fi
  else
    echo -e "${RED}\n❌ Failed to install NVM.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}\n⚠️  NVM already installed. Skipping installation.${NC}"

  nvm install --lts

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}\n✅ Node.js LTS installed successfully using NVM.${NC}"
  else
    echo -e "${RED}\n❌ Failed to install Node.js LTS.${NC}"
    exit 1
  fi
fi

# Copy Neovim and tmux configurations
if [ -d "$HOME/dotfiles/dot_config/nvim" ]; then
  echo -e "${GREEN}\n🚀 Copying Neovim configuration...${NC}"

  mkdir -p "$HOME/.config/nvim"
  cp -r "$HOME/dotfiles/dot_config/nvim/" "$HOME/.config/nvim"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}\n✅ Neovim configuration copied successfully.${NC}"
  else
    echo -e "${RED}\n❌ Failed to copy Neovim configuration.${NC}"
    exit 1
  fi
else
  echo -e "${RED}\n❌ Neovim configuration not found in dotfiles repository. Please fix.${NC}"
fi

echo -e "${GREEN}\n\n✅ All tasks completed successfully.${NC}"
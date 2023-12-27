#!/bin/bash

# Setup latest vim config from https://github.com/amix/vimrc

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 14)"

printf '%s%s%s\n' $COLOR_GREEN 'Cleaning up existing neovim config...' $COLOR_REST
rm -rf ~/.config/nvim
rm -rf ~/.local/share/nvim

printf '%s%s%s\n' $COLOR_GREEN 'Downloading & installing NvChad config...' $COLOR_REST
git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
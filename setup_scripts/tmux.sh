#!/bin/bash

# Setup latest vim config from https://github.com/amix/vimrc

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 14)"

printf '%s%s%s\n' $COLOR_GREEN 'Downloading tmux plugin manager tpm...' $COLOR_REST
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
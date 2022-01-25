#!/bin/bash

# Setup latest vim config from https://github.com/amix/vimrc

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 14)"

printf '%s%s%s\n' $COLOR_GREEN 'Downloading vim config...' $COLOR_REST
git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime

printf '%s%s%s\n' $COLOR_GREEN 'Installing vim config...' $COLOR_REST
sh ~/.vim_runtime/install_awesome_vimrc.sh
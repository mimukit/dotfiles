#!/bin/bash

# Install fisher fish plugin manager
curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher

# Install plugins
fisher install oh-my-fish/plugin-jump
fisher install jorgebucaran/autopair.fish
fisher install jorgebucaran/replay.fish
fisher install PatrickF1/fzf.fish
fisher install markcial/upto
fisher install franciscolourenco/done
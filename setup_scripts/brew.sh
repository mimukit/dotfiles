#!/bin/bash

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 14)"

printf '%s%s%s\n' $COLOR_GREEN 'Updating homebrew...' $COLOR_REST
brew update
brew upgrade

# Install repo sources
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew sources...' $COLOR_REST
brew tap mongodb/brew

# Install packages
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew packages...' $COLOR_REST
apps=(
  act
  ansible
  atuin
  awscli
  bat
  brotli
  btop
  caddy
  chezmoi
  cloudflared
  cmake
  composer
  coreutils
  cryptography
  deno
  dockutil
  eza
  fd
  ffmpeg
  fileicon
  fileicon
  fish
  fzf
  gh
  gifsicle
  git
  gnupg
  go
  grep
  groff
  hostess
  httpie
  hub
  imagemagick
  jq
  lazydocker
  lazygit
  lf
  libpq
  mackup
  mise
  mkcert
  mongocli
  mongodb-database-tools
  mongosh
  mycli
  neovim
  noti
  peco
  percona-toolkit
  peterldowns/tap/localias
  pgcli
  pnpm
  psgrep
  python
  ripgrep
  ruby
  rust
  sesh
  shellcheck
  ssh-copy-id
  sshs
  starship
  svn
  terminal-notifier
  tldr
  tmux
  tmuxinator
  tmuxinator-completion
  trash
  tree
  tree-sitter
  vim
  wget
  zoxide
)

brew install "${apps[@]}"

# Install cask packages
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew cask packages...' $COLOR_REST
cask_apps=(
  1password
  adguard
  aldente
  alt-tab
  android-file-transfer
  android-platform-tools
  arc
  audacity
  bluesnooze
  ccleaner
  chatgpt
  cursor
  daisydisk
  devutils
  docker
  ente-auth
  firefox
  free-download-manager
  google-chrome
  grammarly-desktop
  herd
  iina
  imageoptim
  istat-menus
  iterm2
  jordanbaird-ice
  keycastr
  macupdater
  memory-cleaner
  mongodb-compass
  messenger
  notion
  numi
  obsidian
  orbstack
  postman
  progressive-downloader
  raycast
  shortcat
  shottr
  slack
  spotify
  sublime-text
  surfshark
  tableplus
  telegram-desktop
  ticktick
  toptracker
  tradingview
  visual-studio-code
  vlc
  wezterm
  whatsapp
  windsurf
  zed
  zoom
)

for item in "${cask_apps[@]}"; do
  brew info "${item}" --cask | grep --quiet 'Not installed' && brew install "${item}" --cask
done

printf '%s%s%s\n' $COLOR_GREEN '################# Brew Install Done #################' $COLOR_REST

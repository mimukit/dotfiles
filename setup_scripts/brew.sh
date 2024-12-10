#!/bin/bash

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 14)"

printf '%s%s%s\n' $COLOR_GREEN 'Updating homebrew...' $COLOR_REST
brew update
brew upgrade

# Install repo sources
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew sources...' $COLOR_REST
brew tap homebrew/cask-fonts
brew tap mongodb/brew

# Install packages
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew packages...' $COLOR_REST
apps=(
  act
  atuin
  bat
  btop
  caddy
  chezmoi
  cloudflared
  cmake
  composer
  coreutils
  dockutil
  eza
  fd
  ffmpeg
  fish
  fnm
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
  joshmedeski/sesh/sesh
  lazydocker
  lazygit
  lf
  libpq
  mackup
  mkcert
  mise
  mongosh
  mongodb-database-tools
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
  rustdesk
  shellcheck
  ssh-copy-id
  sshs
  starship
  stremio
  svn
  terminal-notifier
  tldr
  tmux
  tmuxinator
  tree
  vim
  wget
  zoxide
)

brew install "${apps[@]}"

# Install cask packages
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew cask packages...' $COLOR_REST
cask_apps=(
  1password
  adobe-creative-cloud
  alt-tab
  android-file-transfer
  android-platform-tools
  anydesk
  arc
  audacity
  bluesnooze
  chatgpt
  docker
  firefox
  font-fira-code
  font-fira-code-nerd-font
  font-fira-mono-nerd-font
  free-download-manager
  genymotion
  google-chrome
  grammarly-desktop
  herd
  imageoptim
  iterm2
  lm-studio
  local
  macupdater
  messenger
  mochi
  notion
  obsidian
  onedrive
  postman
  raycast
  rustdesk
  setapp
  shortcat
  slack
  spotify
  sublime-text
  telegram-desktop
  tempbox
  ticktick
  toptracker
  tor-browser
  utm
  visual-studio-code
  vlc
  wezterm
  whatsapp
  windsurf
  zoom
)

for item in "${cask_apps[@]}"; do
  brew info "${item}" --cask | grep --quiet 'Not installed' && brew install "${item}" --cask
done

printf '%s%s%s\n' $COLOR_GREEN '################# Brew Install Done #################' $COLOR_REST

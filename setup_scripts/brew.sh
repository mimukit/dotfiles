#!/bin/bash

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 14)"

printf '%s%s%s\n' $COLOR_GREEN 'Updating homebrew...' $COLOR_REST
brew update
brew upgrade

# Install repo sources
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew sources...' $COLOR_REST
brew tap homebrew/cask-fonts

# Install packages
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew packages...' $COLOR_REST
apps=(
    bat
    caddy
    chezmoi
    cmake
    coreutils
    docker
    dockutil
    exa
    fasd
    fd
    ffmpeg
    fish
    fnm
    fzf
    gifsicle
    git
    gnupg
    grep
    groff
    hostess
    httpie
    hub
    imagemagick
    jq
    lf
    libpq
    mackup
    mkcert
    neovim
    noti 
    peco
    percona-toolkit
    pgcli
    pnpm
    psgrep
    python
    shellcheck
    ssh-copy-id
    starship
    svn
    terminal-notifier
    tldr
    tmux
    tree
    vim
    volta
    wget
)

brew install "${apps[@]}"


# Install cask packages
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew cask packages...' $COLOR_REST
cask_apps=(
    android-platform-tools
    anydesk
    authy
    bluesnooze
    brave-browser
    conduktor
    docker
    firefox
    font-fira-code
    font-fira-code-nerd-font
    font-fira-mono-nerd-font
    free-download-manager
    google-chrome
    imageoptim
    iterm2
    latest
    mark-text
    macupdater
    messenger
    mochi
    ngrok
    notion
    postman
    pritunl
    raycast
    rectangle
    responsively
    setapp
    slack
    spotify
    ticktick
    toggl-track
    visual-studio-code
    vivaldi
    vlc
    warp
    whatsapp
    zoom
)

for item in "${cask_apps[@]}"; do
  brew info "${item}" --cask | grep --quiet 'Not installed' && brew install "${item}" --cask
done

printf '%s%s%s\n' $COLOR_GREEN '################# Brew Install Done #################' $COLOR_REST
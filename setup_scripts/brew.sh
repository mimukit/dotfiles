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
    cloudflared
    cmake
    coreutils
    dockutil
    exa
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
    lazydocker
    lf
    libpq
    mackup
    mkcert
    neovim
    noti
    peco
    percona-toolkit
    pgcli
    psgrep
    python
    ripgrep
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
    1password
    alt-tab
    android-file-transfer
    android-platform-tools
    anydesk
    arc
    audacity
    authy
    bluesnooze
    brave-browser
    firefox
    font-fira-code
    font-fira-code-nerd-font
    font-fira-mono-nerd-font
    genymotion
    google-chrome
    grammarly-desktop
    httpie
    imageoptim
    iterm2
    local
    macupdater
    messenger
    microsoft-edge
    mochi
    ngrok
    notion
    obs
    orbstack
    postman
    raycast
    rectangle
    setapp
    slack
    spotify
    sublime-text
    telegram-desktop
    tempbox
    ticktick
    toptracker
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
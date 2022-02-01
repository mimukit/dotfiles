#!/bin/bash

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 14)"

printf '%s%s%s\n' $COLOR_GREEN 'Installing homebrew...' $COLOR_REST
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew update
brew upgrade

# Install repo sources
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew sources...' $COLOR_REST
brew tap homebrew/cask-fonts

# Install packages
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew packages...' $COLOR_REST
apps=(
    cmake
    coreutils
    dockutil
    ffmpeg
    fasd
    gifsicle
    git
    gnu-sed
    grep
    hub
    httpie
    imagemagick
    jq
    mackup
    peco
    psgrep
    python
    shellcheck
    ssh-copy-id
    svn
    tmux
    tree
    vim
    volta
    wget
    chezmoi
    bat
    fish
    gnupg
    starship
    noti 
)

brew install "${apps[@]}"


# Install cask packages
printf '%s%s%s\n' $COLOR_GREEN 'Installing brew cask packages...' $COLOR_REST
cask_apps=(
    raycast
    google-chrome
    iterm2
    visual-studio-code
    postman
    vlc
    free-download-manager
    firefox
    vivaldi
    brave-browser
    slack
    messenger
    setapp
    rectangle
    font-fira-code
    font-fira-code-nerd-font
    font-fira-mono-nerd-font
    font-fira-mono-for-powerline
    spotify
    mark-text
    toggl-track
)

for item in "${cask_apps[@]}"; do
  brew info "${item}" --cask | grep --quiet 'Not installed' && brew install "${item}" --cask
done

printf '%s%s%s\n' $COLOR_GREEN '################# Brew Install Done #################' $COLOR_REST
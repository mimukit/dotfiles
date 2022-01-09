# Install Homebrew

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew update
brew upgrade

# Install packages

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
    
)

brew install "${apps[@]}"


Install cask packages

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
    bitwarden
    rectangle
)

brew install "${cask_apps[@]}" --cask
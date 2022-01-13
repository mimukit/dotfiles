#!/bin/bash

sudo chown -R $(whoami) /usr/local/Cellar
sudo chown -R $(whoami) /usr/local/Homebrew
sudo chown -R $(whoami) /usr/local/var/homebrew
sudo chown -R $(whoami) ${HOME}/Library/Caches/Homebrew
sudo chown -R $(whoami) ${HOME}/Library/Logs/Homebrew
sudo chown -R $(whoami) /usr/local/etc
sudo chown -R $(whoami) /usr/local/opt
sudo chown -R $(whoami) /usr/local/bin
sudo chown -R $(whoami) /usr/local/var
sudo chown -R $(whoami) /usr/local/share/man/man1
sudo chown -R $(whoami) /usr/local/share
sudo chown -R $(whoami) /usr/local/lib
sudo chown -R $(whoami) /usr/local/include
sudo chown -R $(whoami) /usr/local/Frameworks
sudo chown -R $(whoami) /usr/local/Caskroom
sudo chown -R $(whoami) /usr/local/share/zsh
sudo chown -R $(whoami) /usr/local/share/zsh/site-functions
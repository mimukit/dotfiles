#!/bin/bash

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 14)"

printf '%s%s%s\n' $COLOR_GREEN 'Installing volta...' $COLOR_REST
curl https://get.volta.sh | bash

printf '%s%s%s\n' $COLOR_GREEN 'Installing node lts...' $COLOR_REST
volta install node@lts

printf '%s%s%s\n' $COLOR_GREEN 'Installing npm...' $COLOR_REST
volta install npm@latest

printf '%s%s%s\n' $COLOR_GREEN 'Installing yarn v1...' $COLOR_REST
volta install yarn@1

printf '%s%s%s\n' $COLOR_GREEN 'Info volta list...' $COLOR_REST
volta list

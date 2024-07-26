# Automatically loads all the scripts from /config.d directory

# Start the fish shell
if status is-interactive
    # Commands to run in interactive sessions can go here
end
set -gx PATH "/opt/homebrew/bin" $PATH
set -gx PATH "~/.local/share/mise/shims" $PATH
set -gx EDITOR "nvim"

# Disable fish greeting message
set fish_greeting

# Colors for ls command
set -gx LSCOLORS "Cxbgdxdxbxdgeghegeacad"

# Editor
set -x EDITOR nvim
set -x GIT_EDITOR $EDITOR

# Misc
starship init fish | source

source ~/.iterm2_shell_integration.fish
test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

zoxide init --cmd cd fish | source
mise activate fish | source
atuin init --disable-up-arrow fish | source

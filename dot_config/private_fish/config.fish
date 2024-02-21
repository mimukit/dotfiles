# Automatically loads all the scripts from /config.d directory

# Start the fish shell
if status is-interactive
    # Commands to run in interactive sessions can go here
end
set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH
set -gx PATH "/opt/homebrew/bin" $PATH
set -gx EDITOR "nvim"

# Colors for ls command
set -gx LSCOLORS "Cxbgdxdxbxdgeghegeacad"

# Editor
set -x EDITOR nvim
set -x GIT_EDITOR $EDITOR

starship init fish | source
fzf_configure_bindings --git_log=\cg --directory=\cf

source ~/.iterm2_shell_integration.fish
test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

pyenv init - | source
zoxide init --cmd cd fish | source
thefuck --alias | source 
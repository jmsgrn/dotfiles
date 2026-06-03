# $ZDOTDIR/.zshenv - sourced for ALL zsh invocations (login, non-login, scripts)
# Keep this minimal. Heavy interactive setup belongs in .zshrc.

# Path to this dotfiles repo. Edit if you cloned elsewhere, or pre-export
# DOTFILES in your environment to override.
export DOTFILES="${DOTFILES:-$HOME/projects/dotfiles}"

export EDITOR="code --wait"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS="-FRX"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Starship config lives inside the symlinked config/starship/ directory.
export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship/starship.toml"

# $ZDOTDIR/.zshenv - sourced for ALL zsh invocations (login, non-login, scripts)
# Keep this minimal. Heavy interactive setup belongs in .zshrc.

# Path to this dotfiles repo. Edit if you cloned elsewhere, or pre-export
# DOTFILES in your environment to override.
export DOTFILES="${DOTFILES:-$HOME/projects/dotfiles}"

# PATH lives here (not in exports.zsh) because aliases.zsh runs BEFORE exports
# in the .zshrc *.zsh loop, and its `command -v eza` / `command -v zoxide`
# conditionals would fail if PATH didn't already include ~/.local/bin.
# .zshenv runs before any *.zsh sourcing, which fixes the order.
export PATH="${DOTFILES}/bin:${HOME}/.local/bin:${PATH}"

export EDITOR="code --wait"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS="-FRX"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Starship config lives inside the symlinked config/starship/ directory.
export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship/starship.toml"

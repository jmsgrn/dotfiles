# Exports - sourced by .zshrc via ~/.config/zsh/*.zsh glob

# PATH moved to .zshenv so it's set before any *.zsh in $ZDOTDIR sources.
# aliases.zsh's `command -v eza` conditionals were running before exports.zsh
# could prepend ~/.local/bin, leaving them silently un-aliased.

# Colors in less / man
export LESS_TERMCAP_md=$'\e[01;31m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[01;32m'
export LESS_TERMCAP_ue=$'\e[0m'

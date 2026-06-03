# Exports - sourced by .zshrc via ~/.config/zsh/*.zsh glob

# Personal bin on PATH (for scripts like tmux-sessionizer)
export PATH="${DOTFILES}/bin:${HOME}/.local/bin:${PATH}"

# Colors in less / man
export LESS_TERMCAP_md=$'\e[01;31m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[01;32m'
export LESS_TERMCAP_ue=$'\e[0m'

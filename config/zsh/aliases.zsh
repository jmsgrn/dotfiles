# Aliases - sourced by .zshrc via ~/.config/zsh/*.zsh glob

# Listing - eza if installed, plain ls as fallback
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --icons --git --group-directories-first --header'
  alias la='eza -la --icons --git --group-directories-first --header'
  alias tree='eza --tree --icons --git-ignore'
else
  alias ll='ls -lAh'
  alias la='ls -A'
  alias l='ls -CF'
fi

# bat - colored cat (handle Ubuntu's batcat binary name)
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
elif command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
  alias cat='batcat --paging=never'
fi

# fd - modern find (handle Ubuntu's fdfind binary name)
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git
alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git pull'
alias gpu='git push'
alias gl='git log --oneline --graph --decorate -20'
alias gco='git checkout'
alias gb='git branch'
alias gsw='git switch'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Quality of life
# `reload` runs `exec zsh` (clean restart) instead of `source` so cumulative
# state - PATH duplication, lingering aliases removed from the file, plugin
# init that doesn't re-run cleanly - actually resets. Also sources $ZDOTDIR
# not ~/.zshrc, since the latter is just a uv shim on most boxes.
alias reload='exec zsh'
alias path='echo $PATH | tr ":" "\n"'
alias ports='ss -tulpn'

# Editor
alias v='code'

# Claude Code
alias c='claude'
alias ch='claude --chrome'
alias cs='claude --dangerously-skip-permissions'

# Rewrite `--fs` to `--fork-session` before invoking claude.
claude() {
  local args=()
  for arg in "$@"; do
    if [[ "$arg" == "--fs" ]]; then
      args+=("--fork-session")
    else
      args+=("$arg")
    fi
  done
  command claude "${args[@]}"
}

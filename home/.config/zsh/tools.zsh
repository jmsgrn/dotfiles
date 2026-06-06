# Modern CLI tool integrations - sourced via ~/.config/zsh/*.zsh glob
# zoxide, fzf, bat - wired up with cross-platform detection

# -----------------------------------------------------------------------------
# Detect the right binary names (Ubuntu/WSL ships bat as 'batcat', fd as 'fdfind').
# Use `whence -p` not `command -v`: command -v matches aliases too, and
# aliases.zsh runs earlier in the *.zsh loop and may have aliased bat=batcat
# already. fzf evals these strings in a subprocess where aliases don't expand.
# -----------------------------------------------------------------------------
BAT_CMD=""
if whence -p bat >/dev/null; then
  BAT_CMD="bat"
elif whence -p batcat >/dev/null; then
  BAT_CMD="batcat"
fi

# -----------------------------------------------------------------------------
# bat - colored man pages
# -----------------------------------------------------------------------------
if [[ -n "$BAT_CMD" ]]; then
  export MANPAGER="sh -c 'col -bx | $BAT_CMD -l man -p'"
  export MANROFFOPT="-c"
fi

# -----------------------------------------------------------------------------
# zoxide - smart cd, `z foo` jumps to dirs you've visited
# -----------------------------------------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# -----------------------------------------------------------------------------
# fzf - fuzzy finder shell integration
# -----------------------------------------------------------------------------
# Source key-bindings + completion from wherever the OS package put them.
# Order matters: try the most common paths in order.
for f in \
  /usr/share/doc/fzf/examples/key-bindings.zsh \
  /usr/share/fzf/key-bindings.zsh \
  /opt/homebrew/opt/fzf/shell/key-bindings.zsh \
  /usr/local/opt/fzf/shell/key-bindings.zsh; do
  [[ -r "$f" ]] && source "$f" && break
done

for f in \
  /usr/share/doc/fzf/examples/completion.zsh \
  /usr/share/fzf/completion.zsh \
  /opt/homebrew/opt/fzf/shell/completion.zsh \
  /usr/local/opt/fzf/shell/completion.zsh; do
  [[ -r "$f" ]] && source "$f" && break
done

# fzf defaults - 40% height, reverse layout, file preview via bat (if available)
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --preview-window=right:60%"

if [[ -n "$BAT_CMD" ]]; then
  export FZF_CTRL_T_OPTS="--preview '$BAT_CMD --color=always --style=numbers --line-range=:500 {}'"
fi

if command -v eza >/dev/null 2>&1; then
  export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"
fi

# Use fd for fzf if available (faster, respects .gitignore).
# whence -p (not command -v) to avoid matching the fd=fdfind alias.
if whence -p fd >/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
elif whence -p fdfind >/dev/null; then
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
fi

# -----------------------------------------------------------------------------
# history-substring-search keybindings (loaded via antidote)
# Up/Down arrow filters history by what you've typed so far
# -----------------------------------------------------------------------------
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

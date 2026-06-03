# ~/.zshenv - the ONE file that has to live in $HOME.
# zsh reads this for every invocation. All we do here is point zsh at the
# real config dir under $XDG_CONFIG_HOME/zsh/, where the rest of the env,
# rc, plugin list, and history live.
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
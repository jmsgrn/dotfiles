# ~/.zshenv - the ONE file that has to live in $HOME.
# zsh reads this for every invocation. Point ZDOTDIR at the real config dir,
# then load the env file there. (zsh does NOT auto-source $ZDOTDIR/.zshenv -
# only this top-level ~/.zshenv - so we source it explicitly. Without this,
# DOTFILES / PATH / EDITOR never get set in a fresh login.)
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[ -r "$ZDOTDIR/.zshenv" ] && source "$ZDOTDIR/.zshenv"
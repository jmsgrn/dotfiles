#!/usr/bin/env bash
# Shared color + log helpers for bin/dot. Sourced, not executed.
# Honors NO_COLOR and non-tty stderr.

if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  RESET=$'\033[0m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  MAGENTA=$'\033[35m'
  CYAN=$'\033[36m'
else
  RESET='' BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN=''
fi

OK_ICON="✓"
WARN_ICON="!"
ERR_ICON="✗"

log_info()    { printf "  %s%s%s %s\n"          "$BLUE"   "›"         "$RESET" "$*"; }
log_ok()      { printf "  %s%s%s %s\n"          "$GREEN"  "$OK_ICON"  "$RESET" "$*"; }
log_warn()    { printf "  %s%s%s %s\n"          "$YELLOW" "$WARN_ICON" "$RESET" "$*"; }
log_error()   { printf "  %s%s%s %s\n" >&2      "$RED"    "$ERR_ICON" "$RESET" "$*"; }

fmt_cmd()     { printf "%s%s%s" "$MAGENTA$BOLD" "$1" "$RESET"; }
fmt_path()    { printf "%s%s%s" "$CYAN"         "$1" "$RESET"; }
fmt_title()   { printf "\n  %s%s%s\n\n" "$BOLD" "$1" "$RESET"; }

# Replace $HOME prefix with ~ for shorter display.
# Note: we can't use ${p/#$HOME/~} because bash tilde-expands the replacement.
home_tilde() {
  local p="$1"
  if [[ "$p" == "$HOME"* ]]; then
    printf "~%s" "${p#$HOME}"
  else
    printf "%s" "$p"
  fi
}

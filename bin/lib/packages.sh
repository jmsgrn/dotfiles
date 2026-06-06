# packages.sh - the package manifest, sourced by `dot`.
#
# Lists live as plain one-per-line files under bin/packages/ so `dot add` and
# `dot remove` can edit them with a simple append / grep -v. This file just
# reads them into arrays. Kept bash 3.2-compatible (macOS) - no mapfile.

: "${DOTFILES:?packages.sh needs DOTFILES set}"
PKG_DIR="$DOTFILES/bin/packages"

# Read a one-per-line list file into a named array, skipping comments/blanks.
_read_into() {
  local __arr="$1" __f="$2" __line
  eval "$__arr=()"
  [[ -f "$__f" ]] || return 0
  while IFS= read -r __line || [[ -n "$__line" ]]; do
    __line="${__line%%#*}"                 # strip comment
    __line="$(printf '%s' "$__line" | tr -d '[:space:]')"
    [[ -n "$__line" ]] && eval "$__arr+=(\"\$__line\")"
  done < "$__f"
}

_read_into BREW_PKGS  "$PKG_DIR/brew.txt"
_read_into BREW_CASKS "$PKG_DIR/brew-cask.txt"
_read_into APT_PKGS   "$PKG_DIR/apt.txt"
_read_into CURL_PKGS  "$PKG_DIR/curl.txt"

# The list file `dot add`/`dot remove` edit for the current OS's default manager.
manifest_file_for_os() {
  case "${OS:-}" in
    macos) echo "$PKG_DIR/brew.txt" ;;
    *)     echo "$PKG_DIR/apt.txt" ;;
  esac
}

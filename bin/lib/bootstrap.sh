# bootstrap.sh - cross-platform install machinery for `dot init` / `dot update`.
# Pure function definitions (no top-level work). Sourced by bin/dot, which has
# already sourced packages.sh (BREW_PKGS / BREW_CASKS / APT_PKGS / CURL_PKGS)
# and set $DOTFILES + $OS.

# -----------------------------------------------------------------------------
# Logging + spinner (shared by all `dot` commands)
# -----------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_R=$'\033[0m'; C_B=$'\033[34m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_E=$'\033[31m'
else
  C_R='' C_B='' C_G='' C_Y='' C_E=''
fi
info()  { printf "%s==>%s %s\n" "$C_B" "$C_R" "$*"; }
ok()    { printf "%s \xe2\x9c\x93%s %s\n" "$C_G" "$C_R" "$*"; }
warn()  { printf "%s ! %s %s\n" "$C_Y" "$C_R" "$*"; }
err()   { printf "%s \xe2\x9c\x97%s %s\n" "$C_E" "$C_R" "$*" >&2; }

SPIN_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
spin() {
  local label="$1"; shift
  local log rc=0
  log="$(mktemp -t dotfiles-spin.XXXXXX)"
  if [[ ! -t 1 || -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then
    printf "   … %s\n" "$label"
    if "$@" >"$log" 2>&1; then ok "$label"; else rc=$?; err "$label (exit $rc)"; sed 's/^/    /' "$log" >&2; fi
    rm -f "$log"; return $rc
  fi
  printf '\033[?25l'
  "$@" >"$log" 2>&1 &
  local pid=$! i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r %s%s%s %s" "$C_B" "${SPIN_FRAMES[i++ % ${#SPIN_FRAMES[@]}]}" "$C_R" "$label"; sleep 0.08
  done
  if wait "$pid"; then rc=0; else rc=$?; fi
  printf "\r\033[K"; printf '\033[?25h'
  if [[ $rc -eq 0 ]]; then ok "$label"; else err "$label (exit $rc)"; sed 's/^/    /' "$log" >&2; fi
  rm -f "$log"; return $rc
}

# -----------------------------------------------------------------------------
# Preflight + OS detection
# -----------------------------------------------------------------------------
check_prereqs() {
  local missing=()
  command -v git  >/dev/null 2>&1 || missing+=(git)
  command -v curl >/dev/null 2>&1 || missing+=(curl)
  (( ${#missing[@]} == 0 )) && return 0
  err "Missing required tool(s): ${missing[*]}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    err "On macOS:  xcode-select --install   (ships git + curl)"
  elif [[ -r /etc/os-release ]] && grep -qiE 'debian|ubuntu' /etc/os-release; then
    err "On Debian/Ubuntu/WSL:  sudo apt-get update && sudo apt-get install -y ${missing[*]}"
  else
    err "Install them via your platform's package manager, then re-run."
  fi
  exit 1
}

detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then OS="macos"
  elif grep -qi microsoft /proc/version 2>/dev/null; then OS="wsl"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then OS="linux"
  else err "Unsupported OS: $OSTYPE"; exit 1; fi
  export OS
}

# -----------------------------------------------------------------------------
# Per-tool curl installers (Linux; macOS gets these via brew)
# -----------------------------------------------------------------------------
install_starship() { command -v starship >/dev/null 2>&1 && return 0
  spin "Install starship" bash -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y'; }
install_zoxide() { command -v zoxide >/dev/null 2>&1 && return 0
  spin "Install zoxide" bash -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'; }
install_eza() { command -v eza >/dev/null 2>&1 && return 0
  spin "Install eza" bash -c '
    mkdir -p "$HOME/.local/bin" &&
    curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" | tar -xz -C "$HOME/.local/bin" &&
    chmod +x "$HOME/.local/bin/eza"'; }
install_gh() { command -v gh >/dev/null 2>&1 && return 0
  spin "Install gh CLI" bash -c '
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
    sudo apt-get update -y && sudo apt-get install -y gh'; }
install_nvm() {
  [[ -d "$HOME/.nvm" ]] || spin "Install nvm" bash -c 'PROFILE=/dev/null curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
  # nvm ships no node by default; install a Node LTS (pi & other node CLIs need it).
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.nvm/nvm.sh"
    command -v node >/dev/null 2>&1 || spin "Install Node LTS" bash -c '. "$HOME/.nvm/nvm.sh" && nvm install --lts'
  fi
}
install_wezterm() { [[ "$OS" == "wsl" ]] && return 0; command -v wezterm >/dev/null 2>&1 && return 0
  spin "Install WezTerm" bash -c '
    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg &&
    echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null &&
    sudo apt-get update -y && sudo apt-get install -y wezterm'; }
# VS Code *application* (apt repo). Config + extensions are setup_vscode (below).
install_vscode() { [[ "$OS" == "wsl" ]] && return 0; command -v code >/dev/null 2>&1 && return 0
  spin "Install VS Code" bash -c '
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg &&
    sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/keyrings/microsoft.gpg && rm /tmp/microsoft.gpg &&
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null &&
    sudo apt-get update -y && sudo apt-get install -y code'; }

# Pi coding agent (cross-platform; bun/npm global install, no sudo, no TTY).
install_pi() {
  command -v pi >/dev/null 2>&1 && return 0
  if command -v bun >/dev/null 2>&1; then
    spin "Install pi (bun)" bun add -g --ignore-scripts @earendil-works/pi-coding-agent
  elif command -v npm >/dev/null 2>&1; then
    spin "Install pi (npm)" npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  else
    err "pi needs bun or npm on PATH (or run pi.dev/install.sh in a real terminal)."
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Install a single logical package via the OS default manager (for `dot add`).
# -----------------------------------------------------------------------------
pkg_install_one() {
  local pkg="$1"
  case "$OS" in
    macos) spin "brew install $pkg" brew install "$pkg" ;;
    *)     sudo -v; spin "apt install $pkg" sudo apt-get install -y "$pkg" ;;
  esac
}
pkg_remove_one() {
  local pkg="$1"
  case "$OS" in
    macos) spin "brew uninstall $pkg" brew uninstall "$pkg" ;;
    *)     sudo -v; spin "apt remove $pkg" sudo apt-get remove -y "$pkg" ;;
  esac
}

# -----------------------------------------------------------------------------
# Bulk prereq install (used by `dot init`)
# -----------------------------------------------------------------------------
install_prereqs() {
  info "Installing prerequisites..."
  case "$OS" in
    macos)
      if ! command -v brew >/dev/null 2>&1; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      spin "brew install ${BREW_PKGS[*]}" brew install "${BREW_PKGS[@]}"
      spin "brew install --cask ${BREW_CASKS[*]}" brew install --cask "${BREW_CASKS[@]}"
      ;;
    linux|wsl)
      if command -v apt-get >/dev/null 2>&1; then
        sudo -v
        spin "apt-get update" sudo apt-get update -y
        spin "apt-get install ${APT_PKGS[*]}" sudo apt-get install -y "${APT_PKGS[@]}"
        local tool
        for tool in "${CURL_PKGS[@]}"; do "install_$tool"; done
      else
        warn "No supported package manager. Install ${APT_PKGS[*]} ${CURL_PKGS[*]} by hand."
      fi
      ;;
  esac
  ok "Prerequisites ready"
}

# -----------------------------------------------------------------------------
# Update installed packages (used by `dot update`)
# -----------------------------------------------------------------------------
update_packages() {
  case "$OS" in
    macos)
      command -v brew >/dev/null 2>&1 || { warn "brew not found"; return; }
      spin "brew update" brew update
      spin "brew upgrade" brew upgrade
      ;;
    linux|wsl)
      command -v apt-get >/dev/null 2>&1 || { warn "apt-get not found"; return; }
      sudo -v
      spin "apt-get update" sudo apt-get update -y
      spin "apt-get upgrade" sudo apt-get upgrade -y
      local tool   # refresh curl-installed tools (each self-skips if current)
      for tool in "${CURL_PKGS[@]}"; do "install_$tool"; done
      ;;
  esac
}

# -----------------------------------------------------------------------------
# antidote / local git identity / VS Code config / fonts / shell
# -----------------------------------------------------------------------------
install_antidote() {
  if [[ -d "$HOME/.antidote" ]]; then
    spin "Update antidote" git -C "$HOME/.antidote" pull --quiet || true
  else
    spin "Clone antidote" git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi
}

setup_local_files() {
  local local_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/git/config.local"
  if [[ ! -f "$local_cfg" ]]; then
    mkdir -p "$(dirname "$local_cfg")"
    cat > "$local_cfg" <<'EOF'
# Per-machine git identity. Not tracked by the dotfiles repo.
[user]
  # name  = Your Name
  # email = you@example.com
EOF
    ok "Created $local_cfg (edit it to set your git name/email)"
  fi
}

# VS Code config + extensions. On Linux/WSL stow already linked
# home/.config/Code/User -> ~/.config/Code/User; macOS needs the Library path.
setup_vscode() {
  command -v code >/dev/null 2>&1 || { warn "'code' not found - skipping VS Code config/extensions."; return; }
  if [[ "$OS" == "macos" ]]; then
    local dir="$HOME/Library/Application Support/Code/User"; mkdir -p "$dir"
    local f src dest
    for f in settings.json keybindings.json; do
      src="$DOTFILES/home/.config/Code/User/$f"; dest="$dir/$f"
      [[ -e "$src" ]] || continue
      [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]] && continue
      [[ -e "$dest" || -L "$dest" ]] && { mv "$dest" "$dest.bak.$(date +%s)"; warn "moved existing $dest aside"; }
      ln -s "$src" "$dest"; ok "Linked VS Code: $f"
    done
  fi
  info "Installing VS Code extensions..."
  local ext
  while IFS= read -r ext; do
    [[ -z "$ext" || "$ext" =~ ^# ]] && continue
    spin "extension: $ext" code --install-extension "$ext" --force
  done < "$DOTFILES/home/.config/Code/User/extensions.txt"
}

install_fonts() {
  local fonts_root="$DOTFILES/assets/fonts"; [[ -d "$fonts_root" ]] || return 0
  local files=()
  while IFS= read -r -d '' f; do files+=("$f"); done < \
    <(find "$fonts_root" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -print0)
  [[ ${#files[@]} -gt 0 ]] || return 0
  info "Installing ${#files[@]} font file(s)..."
  case "$OS" in
    macos)
      mkdir -p "$HOME/Library/Fonts"; local cnt=0 f
      for f in "${files[@]}"; do [[ -f "$HOME/Library/Fonts/$(basename "$f")" ]] && continue; cp "$f" "$HOME/Library/Fonts/" && cnt=$((cnt+1)); done
      ok "Fonts: $cnt new -> ~/Library/Fonts/" ;;
    linux|wsl)
      mkdir -p "$HOME/.local/share/fonts"; local cnt=0 f
      for f in "${files[@]}"; do [[ -f "$HOME/.local/share/fonts/$(basename "$f")" ]] && continue; cp "$f" "$HOME/.local/share/fonts/" && cnt=$((cnt+1)); done
      command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
      ok "Fonts: $cnt new -> ~/.local/share/fonts/" ;;
  esac
  [[ "$OS" == "wsl" ]] && install_fonts_windows "${files[@]}"
}

install_fonts_windows() {
  local files=("$@") win_user
  win_user="$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')"
  [[ -z "$win_user" || ! -d "/mnt/c/Users/$win_user" ]] && { warn "No Windows username - skipping Windows fonts."; return 0; }
  local win_fonts_dir="/mnt/c/Users/$win_user/AppData/Local/Microsoft/Windows/Fonts"; mkdir -p "$win_fonts_dir"
  local f basename cnt=0
  for f in "${files[@]}"; do basename="$(basename "$f")"
    [[ -f "$win_fonts_dir/$basename" ]] || { cp "$f" "$win_fonts_dir/$basename" && cnt=$((cnt+1)); }
  done
  (( cnt == 0 )) && { ok "Windows fonts: up to date"; return 0; }
  /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    \$ErrorActionPreference='Stop'; Add-Type -AssemblyName PresentationCore
    \$dir=\"\$env:LOCALAPPDATA\Microsoft\Windows\Fonts\"; \$reg='HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    foreach (\$file in Get-ChildItem -Path \$dir -Include *.ttf,*.otf -Recurse -File) {
      try { \$gtf=New-Object Windows.Media.GlyphTypeface -ArgumentList \$file.FullName
        \$family=\$gtf.Win32FamilyNames.Values | Select-Object -First 1; if(-not \$family){\$family=\$file.BaseName}
        \$face=\$gtf.Win32FaceNames.Values | Select-Object -First 1
        if(\$face -and \$face -ne 'Regular'){\$name=\"\$family \$face (TrueType)\"} else {\$name=\"\$family (TrueType)\"}
        Set-ItemProperty -Path \$reg -Name \$name -Value \$file.FullName -Type String
      } catch { Write-Host \"  skip \$(\$file.Name): \$_\" } }
  " >/dev/null 2>&1
  ok "Windows fonts: $cnt new -> $win_fonts_dir (HKCU registered)"
}

install_wezterm_windows_stub() {
  [[ "$OS" == "wsl" ]] || return 0
  [[ -d /mnt/c/Users ]] || { warn "No /mnt/c/Users - skipping WezTerm Windows stub."; return 0; }
  ls "/mnt/c/Program Files/WezTerm/wezterm-gui.exe" "/mnt/c/Users"/*/AppData/Local/Programs/WezTerm/wezterm-gui.exe >/dev/null 2>&1 || return 0
  local win_user; win_user="$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')"
  [[ -z "$win_user" || ! -d "/mnt/c/Users/$win_user" ]] && { warn "No Windows username - skipping WezTerm stub."; return 0; }
  local distro="${WSL_DISTRO_NAME:-Ubuntu}" unc="${HOME#/}"; unc="${unc//\//\\}"
  local target_dir="/mnt/c/Users/$win_user/.config/wezterm" target="$target_dir/wezterm.lua"; mkdir -p "$target_dir"
  [[ -e "$target" ]] && ! grep -q "Windows-side loader stub" "$target" 2>/dev/null && { mv "$target" "$target.bak.$(date +%s)"; warn "moved existing $target aside"; }
  cat >"$target" <<EOF
-- Windows-side loader stub. Real config lives in the WSL dotfiles repo.
return dofile([[\\\\wsl\$\\${distro}\\${unc}\\.dotfiles\\home\\.config\\wezterm\\wezterm.lua]])
EOF
  ok "Wrote WezTerm Windows stub: $target (-> $distro)"
}

snapshot_shell_configs() {
  local backup_dir="$HOME/.dotfiles-backup" ts; ts="$(date +%Y%m%d-%H%M%S)"
  local archive="$backup_dir/shell_configs_$ts.tar.gz"; mkdir -p "$backup_dir"
  local files=(.bashrc .bash_aliases .bash_profile .bash_logout .profile .zshrc .zshenv .zprofile .zlogin)
  local present=() f
  for f in "${files[@]}"; do [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]] && present+=("$f"); done
  [[ ${#present[@]} -eq 0 ]] && return
  tar -czf "$archive" -C "$HOME" "${present[@]}"; ok "Snapshotted shell configs -> $archive"
}

set_default_shell() {
  local current_shell; current_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"; current_shell="${current_shell:-$SHELL}"
  [[ "$current_shell" == *"zsh"* ]] && { ok "zsh is already the login shell ($current_shell)"; return; }
  local zsh_path; zsh_path="$(command -v zsh)"
  grep -q "^${zsh_path}$" /etc/shells 2>/dev/null || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  sudo -v
  if sudo usermod -s "$zsh_path" "$USER" 2>/dev/null || chsh -s "$zsh_path"; then
    ok "Default shell -> $zsh_path (effective on next login; \`exec zsh\` for now)"
  else
    err "Could not change shell. Run:  sudo usermod -s $zsh_path $USER"
  fi
}

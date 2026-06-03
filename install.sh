#!/usr/bin/env bash
#
# install.sh - one-shot bootstrap for jmsgrn/dotfiles
#
# What it does, in order:
#   1. Detect OS (macos, wsl, linux)
#   2. Install prerequisites (zsh, tmux, git, fzf, ripgrep, starship, ...)
#   3. Back up existing files (via `dot backup`)
#   4. Symlink config (via `dot link`) - delegates to bin/dot
#   5. Install antidote (zsh plugin manager)
#   6. Create ~/.config/git/config.local placeholder
#   7. Install VS Code extensions (OS-specific paths handled here, not in dot)
#   8. Switch default shell to zsh
#
# Re-running is safe: `dot link` skips entries that already point at the repo,
# and package installs are no-ops if already present.

set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES="$DOTFILES_DIR"
export PATH="$DOTFILES_DIR/bin:$PATH"

# -----------------------------------------------------------------------------
# Lightweight logging (install.sh has its own; bin/dot has its own)
# -----------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_R=$'\033[0m'; C_B=$'\033[34m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_E=$'\033[31m'
else
  C_R='' C_B='' C_G='' C_Y='' C_E=''
fi
info()  { printf "%s==>%s %s\n" "$C_B" "$C_R" "$*"; }
ok()    { printf "%s ✓%s %s\n" "$C_G" "$C_R" "$*"; }
warn()  { printf "%s ! %s %s\n" "$C_Y" "$C_R" "$*"; }
err()   { printf "%s ✗%s %s\n" "$C_E" "$C_R" "$*" >&2; }

# -----------------------------------------------------------------------------
# Spinner: run command in background with a progress indicator.
# Usage:
#   spin "Label" some_cmd arg1 arg2
#   spin "Label" bash -c 'curl ... | tar ...'   # for pipelines
# On failure prints captured output; exit status is propagated.
# -----------------------------------------------------------------------------
SPIN_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

spin() {
  local label="$1"; shift
  local log rc=0
  log="$(mktemp -t dotfiles-spin.XXXXXX)"

  # No TTY / NO_COLOR / dumb terminal: run inline without animation.
  if [[ ! -t 1 || -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then
    printf "   … %s\n" "$label"
    if "$@" >"$log" 2>&1; then
      ok "$label"
    else
      rc=$?
      err "$label (exit $rc)"
      sed 's/^/    /' "$log" >&2
    fi
    rm -f "$log"
    return $rc
  fi

  # Hide cursor for the duration.
  printf '\033[?25l'

  "$@" >"$log" 2>&1 &
  local pid=$! i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r %s%s%s %s" "$C_B" "${SPIN_FRAMES[i++ % ${#SPIN_FRAMES[@]}]}" "$C_R" "$label"
    sleep 0.08
  done

  # Use wait without tripping set -e on non-zero.
  if wait "$pid"; then rc=0; else rc=$?; fi

  # Clear the spinner line, restore cursor.
  printf "\r\033[K"
  printf '\033[?25h'

  if [[ $rc -eq 0 ]]; then
    ok "$label"
  else
    err "$label (exit $rc)"
    sed 's/^/    /' "$log" >&2
  fi
  rm -f "$log"
  return $rc
}

# Make sure the cursor comes back even if we get killed mid-spin.
trap 'printf "\033[?25h"' EXIT INT TERM

# -----------------------------------------------------------------------------
# 0. Preflight - bail loudly if the meta-prereqs aren't on PATH.
#
# `bash` and a writable $HOME are taken for granted (we're running). Everything
# below assumes `git` (cloning antidote, etc.) and `curl` (Homebrew bootstrap,
# starship/zoxide/eza installers). If either is missing we fail fast with a
# platform-specific hint, instead of crashing partway through with a less
# obvious error.
# -----------------------------------------------------------------------------
check_prereqs() {
  local missing=()
  command -v git  >/dev/null 2>&1 || missing+=(git)
  command -v curl >/dev/null 2>&1 || missing+=(curl)
  (( ${#missing[@]} == 0 )) && return 0

  err "Missing required tool(s): ${missing[*]}"
  err "install.sh needs these on the PATH before it can bootstrap anything."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    err "On macOS:  xcode-select --install   (ships git + curl)"
  elif [[ -r /etc/os-release ]] && grep -qiE 'debian|ubuntu' /etc/os-release; then
    err "On Debian/Ubuntu/WSL:  sudo apt-get update && sudo apt-get install -y ${missing[*]}"
  else
    err "Install them via your platform's package manager, then re-run."
  fi
  exit 1
}

# -----------------------------------------------------------------------------
# 1. OS detect
# -----------------------------------------------------------------------------
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    OS="wsl"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
  else
    err "Unsupported OS: $OSTYPE"; exit 1
  fi
  info "Detected OS: $OS"
}

# -----------------------------------------------------------------------------
# 2. Prereqs
#
# Edit the lists below to add or drop tools - the install logic below stays
# generic. Anything referenced from a config file in this repo should appear
# in at least one of these lists so a fresh-machine bootstrap is complete.
# -----------------------------------------------------------------------------

# Homebrew package list (macOS, single shot).
BREW_PKGS=(
  zsh tmux git
  fzf ripgrep jq bat fd
  starship zoxide eza
  gh                       # used by git credential helper and `gh repo create`
  unzip                    # used by install.sh (font extraction) and `extract` fn
)

# Homebrew casks (macOS GUI apps).
BREW_CASKS=(
  wezterm
  visual-studio-code
)

# apt package list (Debian/Ubuntu/WSL). Some tools below are too old in apt -
# those are installed via curl in LINUX_CURL_INSTALLS instead.
APT_PKGS=(
  zsh tmux git
  fzf ripgrep jq curl
  bat                      # binary is `batcat` on Debian, aliased in aliases.zsh
  fd-find                  # binary is `fdfind` on Debian, aliased in aliases.zsh
  unzip
)

# Tools curl-installed on Linux because apt doesn't ship a recent version,
# or doesn't ship them at all. macOS gets these via brew above.
LINUX_CURL_INSTALLS=(starship zoxide eza gh nvm wezterm vscode)

install_starship() {
  command -v starship >/dev/null 2>&1 && return 0
  spin "Install starship" bash -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
}

install_zoxide() {
  command -v zoxide >/dev/null 2>&1 && return 0
  spin "Install zoxide" bash -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
}

install_eza() {
  command -v eza >/dev/null 2>&1 && return 0
  # Pinned x86_64-gnu - swap arch if you ever boot this on arm64 Linux.
  spin "Install eza" bash -c '
    mkdir -p "$HOME/.local/bin" &&
    curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" \
      | tar -xz -C "$HOME/.local/bin" &&
    chmod +x "$HOME/.local/bin/eza"
  '
}

install_gh() {
  command -v gh >/dev/null 2>&1 && return 0
  # The official Debian/Ubuntu install recipe: add the GitHub apt repo, then install.
  spin "Install gh CLI" bash -c '
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
    sudo apt-get update -y &&
    sudo apt-get install -y gh
  '
}

install_nvm() {
  [[ -d "$HOME/.nvm" ]] && return 0
  # PROFILE=/dev/null prevents the installer from editing ~/.bashrc / ~/.zshrc -
  # this repo already loads nvm in config/zsh/.zshrc, we do not want a second
  # source line scribbled into user-owned dotfiles.
  spin "Install nvm" bash -c '
    PROFILE=/dev/null curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  '
}

# WezTerm on Debian/Ubuntu/Pop via the official Fury apt repo.
# Skipped on WSL because there WezTerm runs as a Windows process and the
# install lives on the Windows side (with our wezterm.lua stub).
install_wezterm() {
  [[ "$OS" == "wsl" ]] && return 0
  command -v wezterm >/dev/null 2>&1 && return 0
  spin "Install WezTerm" bash -c '
    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg &&
    echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null &&
    sudo apt-get update -y &&
    sudo apt-get install -y wezterm
  '
}

# VS Code on Debian/Ubuntu/Pop via the official Microsoft apt repo.
# Skipped on WSL because there VS Code is a Windows install and the `code`
# command is bridged through from Windows.
install_vscode() {
  [[ "$OS" == "wsl" ]] && return 0
  command -v code >/dev/null 2>&1 && return 0
  spin "Install VS Code" bash -c '
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg &&
    sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/keyrings/microsoft.gpg &&
    rm /tmp/microsoft.gpg &&
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null &&
    sudo apt-get update -y &&
    sudo apt-get install -y code
  '
}

install_prereqs() {
  info "Installing prerequisites..."
  case "$OS" in
    macos)
      if ! command -v brew >/dev/null 2>&1; then
        info "Installing Homebrew..."
        # Homebrew's installer prompts for sudo and prints lots of output: do not spin.
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      spin "brew install ${BREW_PKGS[*]}" brew install "${BREW_PKGS[@]}"
      spin "brew install --cask ${BREW_CASKS[*]}" brew install --cask "${BREW_CASKS[@]}"
      ;;
    linux|wsl)
      if command -v apt-get >/dev/null 2>&1; then
        # Cache sudo creds up front so prompts don't get hidden behind spinners.
        sudo -v
        spin "apt-get update" sudo apt-get update -y
        spin "apt-get install ${APT_PKGS[*]}" sudo apt-get install -y "${APT_PKGS[@]}"
        local tool
        for tool in "${LINUX_CURL_INSTALLS[@]}"; do
          "install_$tool"
        done
      else
        warn "No supported package manager. Install ${APT_PKGS[*]} ${LINUX_CURL_INSTALLS[*]} by hand."
      fi
      ;;
  esac
  ok "Prerequisites ready"
}

# -----------------------------------------------------------------------------
# 3 + 4. Backup then symlink via bin/dot
# -----------------------------------------------------------------------------

# Safety-net backup: snapshot well-known shell rc files that `dot backup`
# wouldn't otherwise touch (the repo doesn't manage ~/.bashrc, etc., so any
# user content there gets silently bypassed when chsh switches to zsh).
snapshot_shell_configs() {
  local backup_dir="$HOME/.dotfiles-backup"
  local ts; ts="$(date +%Y%m%d-%H%M%S)"
  local archive="$backup_dir/shell_configs_$ts.tar.gz"
  mkdir -p "$backup_dir"

  local files=(
    .bashrc .bash_aliases .bash_profile .bash_logout .profile
    .zshrc .zshenv .zprofile .zlogin
  )
  local present=()
  local f
  for f in "${files[@]}"; do
    # Snapshot only real files - skip symlinks we've already created.
    [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]] && present+=("$f")
  done

  if [[ ${#present[@]} -eq 0 ]]; then
    return
  fi

  tar -czf "$archive" -C "$HOME" "${present[@]}"
  ok "Snapshotted shell configs -> $archive"
}

run_dot() {
  info "Snapshotting shell rc files (safety net)..."
  snapshot_shell_configs
  info "Backing up existing config..."
  dot backup
  info "Linking config (replacing any non-symlink originals)..."
  dot link --force
}

# -----------------------------------------------------------------------------
# 5. antidote (zsh plugin manager)
# -----------------------------------------------------------------------------
install_antidote() {
  if [[ -d "$HOME/.antidote" ]]; then
    spin "Update antidote" git -C "$HOME/.antidote" pull --quiet || true
  else
    spin "Clone antidote" git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
  fi
}

# -----------------------------------------------------------------------------
# 6. Local git identity placeholder (untracked - personal name/email goes here)
# -----------------------------------------------------------------------------
setup_local_files() {
  local local_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/git/config.local"
  if [[ ! -f "$local_cfg" ]]; then
    mkdir -p "$(dirname "$local_cfg")"
    cat > "$local_cfg" <<'EOF'
# Per-machine git identity. Not tracked by the dotfiles repo.
# Uncomment and fill in:
[user]
  # name  = Your Name
  # email = you@example.com
EOF
    ok "Created $local_cfg (edit it to set your git name/email)"
  fi
}

# -----------------------------------------------------------------------------
# 7. VS Code (OS-specific paths - not handled by dot link)
# -----------------------------------------------------------------------------
install_vscode() {
  if ! command -v code >/dev/null 2>&1; then
    warn "'code' command not found - skipping VS Code config and extensions."
    return
  fi

  local vscode_user_dir
  case "$OS" in
    macos)     vscode_user_dir="$HOME/Library/Application Support/Code/User" ;;
    linux|wsl) vscode_user_dir="$HOME/.config/Code/User" ;;
  esac
  mkdir -p "$vscode_user_dir"

  local f
  for f in settings.json keybindings.json; do
    local src="$DOTFILES_DIR/config/vscode/$f"
    local dest="$vscode_user_dir/$f"
    [[ -e "$src" ]] || continue
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      continue
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
      mv "$dest" "$dest.bak.$(date +%s)"
      warn "Moved existing $dest -> $dest.bak.<ts>"
    fi
    ln -s "$src" "$dest"
    ok "Linked VS Code: $f"
  done

  info "Installing VS Code extensions..."
  while IFS= read -r ext; do
    [[ -z "$ext" || "$ext" =~ ^# ]] && continue
    spin "extension: $ext" code --install-extension "$ext" --force
  done < "$DOTFILES_DIR/config/vscode/extensions.txt"
}

# -----------------------------------------------------------------------------
# 7a. Fonts - install everything under assets/fonts/ into the OS font dir.
# On WSL we also push to the Windows side because WezTerm/Windows Terminal
# are Windows GUIs and only see Windows-registered fonts.
# -----------------------------------------------------------------------------
install_fonts() {
  local fonts_root="$DOTFILES_DIR/assets/fonts"
  [[ -d "$fonts_root" ]] || return 0

  # Gather all ttf/otf files (any subdir, e.g. cascadia-code/).
  local files=()
  while IFS= read -r -d '' f; do files+=("$f"); done < \
    <(find "$fonts_root" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -print0)
  [[ ${#files[@]} -gt 0 ]] || return 0

  info "Installing ${#files[@]} font file(s)..."

  case "$OS" in
    macos)
      mkdir -p "$HOME/Library/Fonts"
      local cnt=0
      for f in "${files[@]}"; do
        [[ -f "$HOME/Library/Fonts/$(basename "$f")" ]] && continue
        cp "$f" "$HOME/Library/Fonts/" && cnt=$((cnt + 1))
      done
      ok "Fonts: $cnt new -> ~/Library/Fonts/"
      ;;
    linux|wsl)
      mkdir -p "$HOME/.local/share/fonts"
      local cnt=0
      for f in "${files[@]}"; do
        [[ -f "$HOME/.local/share/fonts/$(basename "$f")" ]] && continue
        cp "$f" "$HOME/.local/share/fonts/" && cnt=$((cnt + 1))
      done
      command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
      ok "Fonts: $cnt new -> ~/.local/share/fonts/"
      ;;
  esac

  [[ "$OS" == "wsl" ]] && install_fonts_windows "${files[@]}"
}

# Install fonts on the Windows side, per-user, no admin required.
# Files go to %LOCALAPPDATA%\Microsoft\Windows\Fonts\ and a registry entry
# is added under HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts.
install_fonts_windows() {
  local files=("$@")
  local win_user
  win_user="$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')"
  if [[ -z "$win_user" || ! -d "/mnt/c/Users/$win_user" ]]; then
    warn "Could not detect Windows username - skipping Windows-side font install."
    return 0
  fi

  local win_fonts_dir="/mnt/c/Users/$win_user/AppData/Local/Microsoft/Windows/Fonts"
  mkdir -p "$win_fonts_dir"

  local f basename cnt=0
  for f in "${files[@]}"; do
    basename="$(basename "$f")"
    if [[ ! -f "$win_fonts_dir/$basename" ]]; then
      cp "$f" "$win_fonts_dir/$basename" && cnt=$((cnt + 1))
    fi
  done

  if (( cnt == 0 )); then
    ok "Windows fonts: already up to date"
    return 0
  fi

  # Register every TTF/OTF in the user font dir against HKCU. PresentationCore's
  # GlyphTypeface gives us the canonical family name without parsing the file ourselves.
  /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    \$ErrorActionPreference = 'Stop'
    Add-Type -AssemblyName PresentationCore
    \$dir = \"\$env:LOCALAPPDATA\Microsoft\Windows\Fonts\"
    \$reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    foreach (\$file in Get-ChildItem -Path \$dir -Include *.ttf,*.otf -Recurse -File) {
      try {
        \$gtf = New-Object -TypeName Windows.Media.GlyphTypeface -ArgumentList \$file.FullName
        \$family = \$gtf.Win32FamilyNames.Values | Select-Object -First 1
        if (-not \$family) { \$family = \$file.BaseName }
        \$face = \$gtf.Win32FaceNames.Values | Select-Object -First 1
        if (\$face -and \$face -ne 'Regular') { \$name = \"\$family \$face (TrueType)\" }
        else { \$name = \"\$family (TrueType)\" }
        Set-ItemProperty -Path \$reg -Name \$name -Value \$file.FullName -Type String
      } catch {
        Write-Host \"  skip \$(\$file.Name): \$_\"
      }
    }
  " >/dev/null 2>&1

  ok "Windows fonts: $cnt new -> $win_fonts_dir (HKCU registered)"
}

# -----------------------------------------------------------------------------
# 7b. WezTerm on Windows (WSL only)
#
# WezTerm runs as a Windows process and reads its config from the Windows
# user profile, not from inside WSL. Without a config on that side it boots
# into PowerShell instead of dropping into the WSL distro.
#
# Solution: drop a tiny loader stub on the Windows side that `dofile`s the
# real config out of \\wsl$\<distro>\... - keeps the WSL repo as the single
# source of truth.
# -----------------------------------------------------------------------------
install_wezterm_windows_stub() {
  [[ "$OS" == "wsl" ]] || return 0

  local win_user_dir="/mnt/c/Users"
  [[ -d "$win_user_dir" ]] || { warn "No /mnt/c/Users - skipping WezTerm Windows stub."; return 0; }

  # WezTerm not installed on the Windows side? Nothing to wire up.
  if ! ls "/mnt/c/Program Files/WezTerm/wezterm-gui.exe" "/mnt/c/Users"/*/AppData/Local/Programs/WezTerm/wezterm-gui.exe >/dev/null 2>&1; then
    return 0
  fi

  local win_user
  win_user="$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')"
  if [[ -z "$win_user" || ! -d "$win_user_dir/$win_user" ]]; then
    warn "Could not detect Windows username - skipping WezTerm stub."
    return 0
  fi

  local distro="${WSL_DISTRO_NAME:-Ubuntu}"
  local wsl_home_in_unc="${HOME#/}"   # strip leading slash for UNC join
  wsl_home_in_unc="${wsl_home_in_unc//\//\\}"   # /home/jgreen -> home\jgreen
  local target_dir="$win_user_dir/$win_user/.config/wezterm"
  local target="$target_dir/wezterm.lua"

  mkdir -p "$target_dir"

  # If an existing file isn't our stub, move it aside.
  if [[ -e "$target" ]] && ! grep -q "Windows-side loader stub" "$target" 2>/dev/null; then
    mv "$target" "$target.bak.$(date +%s)"
    warn "Moved existing $target -> $target.bak.<ts>"
  fi

  cat >"$target" <<EOF
-- Windows-side loader stub.
-- The real config lives in the WSL dotfiles repo so this Windows file and the
-- one inside WSL never drift. WezTerm on Windows can read files over the
-- \\\\wsl\$\\<distro>\\... UNC mount.
return dofile([[\\\\wsl\$\\${distro}\\${wsl_home_in_unc}\\projects\\dotfiles\\config\\wezterm\\wezterm.lua]])
EOF
  ok "Wrote WezTerm Windows stub: $target (-> $distro)"
}

# -----------------------------------------------------------------------------
# 8. Default shell -> zsh
# -----------------------------------------------------------------------------
set_default_shell() {
  # Authoritative check - $SHELL is the env var, /etc/passwd is the truth.
  local current_shell
  current_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
  current_shell="${current_shell:-$SHELL}"
  if [[ "$current_shell" == *"zsh"* ]]; then
    ok "zsh is already the login shell ($current_shell)"
    return
  fi

  # Heads-up if the user has substantive bash config that won't follow them.
  # The pre-install snapshot already captured everything to ~/.dotfiles-backup/,
  # so this is informational, not a gate.
  if [[ "$current_shell" == *"bash"* && -f "$HOME/.bashrc" ]]; then
    local bash_rc_size; bash_rc_size=$(wc -c <"$HOME/.bashrc")
    if (( bash_rc_size > 8192 )); then
      echo
      warn "Your ~/.bashrc is $bash_rc_size bytes - aliases/functions/exports there"
      warn "will NOT auto-port into zsh. Snapshot is at ~/.dotfiles-backup/"
      warn "shell_configs_*.tar.gz; port what you need into ~/.config/zsh/local.zsh"
      warn "(gitignored) or the tracked zsh files. Continuing with chsh anyway."
      echo
    fi
  fi

  local zsh_path; zsh_path="$(command -v zsh)"
  if ! grep -q "^${zsh_path}$" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi

  # Use `usermod` instead of `chsh` because chsh goes through PAM and can fail
  # silently on some distros (Pop!_OS observed). usermod writes /etc/passwd
  # directly. Refresh sudo creds in case they lapsed during the long apt phase.
  sudo -v
  if sudo usermod -s "$zsh_path" "$USER"; then
    local new_shell; new_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$new_shell" == "$zsh_path" ]]; then
      ok "Default shell -> $new_shell (effective on next login or in a new tab)"
      info "Drop into zsh in this terminal right now with:  exec zsh"
    else
      err "usermod returned 0 but /etc/passwd still says $new_shell. Investigate."
      return 1
    fi
  else
    err "usermod failed. Run this by hand:  sudo usermod -s $zsh_path $USER"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  info "Bootstrapping dotfiles from $DOTFILES_DIR"
  check_prereqs
  detect_os
  install_prereqs
  chmod +x "$DOTFILES_DIR/bin/"* 2>/dev/null || true
  run_dot
  install_antidote
  setup_local_files
  install_vscode
  install_fonts
  install_wezterm_windows_stub
  set_default_shell

  echo
  ok "Done. Open a new shell to pick up the changes."
  echo "    Backups (if any) live in: ~/.dotfiles-backup/"
  echo "    Day-to-day: \`dot link\`, \`dot unlink\`, \`dot backup\`, \`dot clean\`"
}

main "$@"

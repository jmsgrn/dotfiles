# dotfiles

My personal cross-platform config - WezTerm, zsh, tmux, Starship, Git, VS Code. Same setup on macOS, Linux, and WSL.

## Install

### Prereqs

`install.sh` bootstraps everything else (Homebrew on macOS, apt-installed tools on Linux/WSL, plus a handful of curl-installed binaries). It needs three things on PATH before it can run:

- **`bash`** - to execute the script
- **`git`** - to clone this repo and a couple of helpers (antidote, etc.)
- **`curl`** - used by the Homebrew installer, starship, zoxide, eza, gh, nvm

What you do *not* need: a preinstalled package manager. On macOS the script installs Homebrew if it's missing. On Debian/Ubuntu/WSL `apt-get` is always present. On other Linux distros (Fedora, Arch, etc.) the script will warn and you'll need to install the package list by hand.

Quick way to get the meta-prereqs:

| Platform | Command |
|---|---|
| macOS | `xcode-select --install` (ships git + curl) |
| Debian/Ubuntu/WSL | `sudo apt-get update && sudo apt-get install -y git curl` |

### Run it

Clone anywhere you like - the repo is location-independent. My convention is `~/projects/dotfiles`:

```sh
git clone https://github.com/jmsgrn/dotfiles ~/projects/dotfiles
cd ~/projects/dotfiles
./install.sh
```

If you clone somewhere other than `~/projects/dotfiles`, pre-export `DOTFILES` in your environment (or edit `home/.zshenv`). Everything else resolves through `$DOTFILES`.

`install.sh` installs prerequisites and then delegates symlinking to `dot link`. Existing config gets tarballed to `~/.dotfiles-backup/dotfiles_backup_<timestamp>.tar.gz` first. Safe to re-run.

## The `dot` CLI

Day-to-day, manage symlinks with `bin/dot` (added to `$PATH` by `exports.zsh`):

| Command | What it does |
|---|---|
| `dot help` | usage |
| `dot link [-f] [pkg]` | symlink `config/<pkg>` → `~/.config/<pkg>` and `home/<file>` → `~/<file>` (default: all). `-f`/`--force` removes existing non-symlink files first (back them up with `dot backup` first if you care). |
| `dot unlink [pkg]` | remove our symlinks (default: all) |
| `dot backup` | tar files we'd replace into `~/.dotfiles-backup/` |
| `dot clean` | remove broken symlinks pointing into `$DOTFILES` |

Adding a new tool is just: drop a directory in `config/` (gets linked into `~/.config/`) or a dotfile in `home/` (gets linked into `~/`). `dot link` picks it up automatically - no hardcoded list to edit.

## What's inside

- **WezTerm** - cross-platform GPU terminal, single Lua config
- **zsh + antidote** - fast plugin loading, OMZ plugins without the framework. Config lives under `$XDG_CONFIG_HOME/zsh/` via `ZDOTDIR`; the only thing in `$HOME` is a one-line `~/.zshenv` that sets `ZDOTDIR`.
- **Starship** - cross-shell prompt
- **tmux** - persistent sessions with vim-style splits and the Primeagen `tmux-sessionizer`. Config at `$XDG_CONFIG_HOME/tmux/tmux.conf` (tmux 3.1+).
- **Modern CLI tools** - `zoxide` (smart cd), `fzf` (fuzzy finder), `bat` (cat with colors), `eza` (modern ls), `fd` (modern find), `ripgrep`
- **Git** - sensible defaults at `$XDG_CONFIG_HOME/git/config`, global gitignore at `$XDG_CONFIG_HOME/git/ignore`. Identity is kept in untracked `~/.config/git/config.local` (created by `install.sh`).
- **VS Code** - settings, keybindings, and an `extensions.txt` that gets auto-installed

## Layout

```
dotfiles/
├── install.sh             # bootstrap: prereqs + dot link + antidote + VS Code
├── README.md
├── LICENSE
├── bin/
│   ├── dot                # symlink/backup/clean CLI
│   ├── lib/common.sh      # shared logging/color helpers
│   └── tmux-sessionizer
├── config/                # dot link -> $XDG_CONFIG_HOME/<pkg>
│   ├── zsh/               # .zshenv, .zshrc, .zsh_plugins.txt, aliases.zsh, functions.zsh, exports.zsh, tools.zsh
│   ├── git/               # config, ignore (XDG-native, no dot prefix)
│   ├── tmux/              # tmux.conf
│   ├── wezterm/           # wezterm.lua
│   ├── starship/          # starship.toml (STARSHIP_CONFIG points here)
│   └── vscode/            # settings.json, keybindings.json, extensions.txt
│                          # (OS-specific install path - linked by install.sh, skipped by dot)
└── home/                  # dot link -> $HOME/<file>
    └── .zshenv            # one line: sets ZDOTDIR so zsh finds config/zsh/
```

## Shortcuts and aliases I actually use

### fzf - in any zsh session

| Key | Action |
|---|---|
| `Ctrl-T` | fuzzy file search at the cursor (with `bat` preview) |
| `Ctrl-R` | fuzzy history search |
| `Alt-C` | fuzzy `cd` into a directory (with `eza --tree` preview) |
| `**` + Tab | trigger fuzzy completion for any command |

### zoxide - smart cd

| Command | Action |
|---|---|
| `z foo` | jump to the most-visited dir matching "foo" |
| `z foo bar` | jump to the dir matching both |
| `zi` | interactive selection from your zoxide history |

### History substring search

Start typing a command then press `Up` / `Down` - filters history to commands that begin with what you've typed.

### Modern CLI aliases

| Alias | Runs |
|---|---|
| `ls` / `ll` / `la` / `tree` | `eza` with icons, git status, group dirs first |
| `cat <file>` | `bat` with syntax highlighting |
| `fd <pat>` | works whether the binary is `fd` or `fdfind` (Ubuntu) |
| `man <cmd>` | uses `bat` as the pager - colored, syntax-highlighted man pages |

### tmux (prefix = `Ctrl-Space`)

| Key | Action |
|---|---|
| `prefix` `\|` | split pane vertically (keeps current dir) |
| `prefix` `-` | split pane horizontally (keeps current dir) |
| `prefix` `c` | new window |
| `prefix` `d` | detach (session keeps running) |
| `prefix` `h/j/k/l` | navigate panes vim-style |
| `prefix` `H/J/K/L` | resize panes (hold and repeat) |
| `prefix` `r` | reload `.tmux.conf` |
| `prefix` `[` | enter copy mode (vim keys: `v` select, `y` yank) |
| `tmux a` | attach to last session |
| `tmux ls` | list sessions |

### tmux-sessionizer (Primeagen pattern)

Fuzzy-find a project directory and either create-or-attach a tmux session named after it. Bound to a global key.

```sh
bindkey -s '^f' '^utmux-sessionizer\n'   # Ctrl-f
```

### zsh aliases

| Alias | Expands to |
|---|---|
| `ll` | `ls -lAh` |
| `..` / `...` / `....` | `cd ..` (one/two/three up) |
| `gs` | `git status` |
| `gd` / `gds` | `git diff` / `git diff --staged` |
| `gcm "msg"` | `git commit -m "msg"` |
| `gcam "msg"` | `git add -A && git commit -m "msg"` (function) |
| `gp` / `gpu` | `git pull` / `git push` |
| `gl` | `git log --oneline --graph --decorate -20` |
| `gco` / `gsw` / `gb` | `git checkout` / `git switch` / `git branch` |
| `reload` | `source ~/.zshrc` |
| `path` | print `$PATH` one entry per line |
| `mkcd <dir>` | mkdir + cd in one shot |
| `extract <file>` | extract any common archive |

### VS Code

| Key | Action |
|---|---|
| `Ctrl-P` | quick file open |
| `Ctrl-Shift-P` | command palette |
| `` Ctrl-` `` | toggle integrated terminal |
| `Ctrl-Shift-E` | reveal in explorer |

### WezTerm (Mac: `Cmd`, Linux/WSL: `Ctrl-Shift`)

| Key | Action |
|---|---|
| `mod-t` | new tab |
| `mod-w` | close tab |
| `mod-[ / mod-]` | prev / next tab |
| `mod-d` | split pane vertically |
| `mod-shift-d` | split pane horizontally |

## Per-machine overrides (not tracked)

These files get sourced if present, ignored if missing - your secrets / work identity / box-specific tweaks live here:

| File | What it's for |
|---|---|
| `~/.config/git/config.local` | git user.name / user.email (created by install.sh) |
| `~/.config/zsh/work.zsh` | work-only aliases/paths/env (drop a real file here on the work box) |
| `~/.config/zsh/*.local.zsh` | any per-machine zsh you want sourced |

The `.zshrc` glob `$ZDOTDIR/*.zsh` (== `~/.config/zsh/*.zsh`) picks them all up automatically.

## License

MIT

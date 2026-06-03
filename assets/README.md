# assets/

Binary assets that travel with this repo so a fresh machine bootstrap gets
the same look and feel as every other machine.

- `fonts/` - typefaces installed by `install.sh` into the OS font dir.
  On WSL the install also installs them on the Windows side, since the GUI
  apps (WezTerm, Windows Terminal) run as Windows processes.
- `backgrounds/` - wallpapers / terminal background images. Reference
  them from `config/wezterm/wezterm.lua` or wherever you want them used.

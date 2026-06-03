# Cascadia Code

Microsoft's monospaced font - the default for Windows Terminal, used by
this repo's WezTerm config and Windows Terminal profile.

## What's vendored here

| File | Purpose |
|---|---|
| `CascadiaCode.ttf` | Variable font, upright. Covers Regular through Bold via weight axis. |
| `CascadiaCodeItalic.ttf` | Variable font, italic. |
| `LICENSE` | SIL Open Font License 1.1 (the font's redistribution terms). |

Why variable fonts instead of the static per-weight files: ~1.2 MB total
vs. ~5 MB+ for the static set, and weight axis still works at every value
font consumers care about.

## Updating

Pulled from <https://github.com/microsoft/cascadia-code/releases>. To
refresh:

```bash
curl -fsSL -o /tmp/cc.zip \
  "$(curl -fsSL https://api.github.com/repos/microsoft/cascadia-code/releases/latest \
     | python3 -c 'import sys,json; print(next(a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith(".zip")))')"
unzip -j /tmp/cc.zip "ttf/CascadiaCode.ttf" "ttf/CascadiaCodeItalic.ttf" \
  -d assets/fonts/cascadia-code/
rm /tmp/cc.zip
```

# Oh My Zsh Installer (Git Bash on Windows)

This project installs and configures Oh My Zsh in Git Bash on Windows.

It sets up:
- Oh My Zsh
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- Theme selection by name
- Auto-start zsh when opening Git Bash

## Files

- `bootstrap.sh` - entrypoint for users
- `install_gitbash_ohmyzsh.sh` - main installer logic

## Requirements

- Windows + Git Bash
- `git`
- `curl` or `wget`
- `winget` (only needed if `zsh.exe` is missing from Git for Windows)

## Install

From Git Bash in this folder:

```bash
chmod +x bootstrap.sh install_gitbash_ohmyzsh.sh
./bootstrap.sh
```

Then close and reopen Git Bash.

## Theme Selection

During install, enter a theme name (for example: `robbyrussell`, `agnoster`, `bira`).

Theme list and screenshots:
- https://github.com/ohmyzsh/ohmyzsh/wiki/Themes

If a theme is not available locally, installer will try official Oh My Zsh themes.
If still not found, it asks for a direct theme URL.

## Autosuggestion Usage

After install, suggestions appear in faded text while you type.

- Type part of a previous command (example: `git st`)
- Accept suggestion with Right Arrow (`->`) key
- You can also use `Ctrl+f` to accept

Note: typing `>` is not the same as Right Arrow.

## Non-Interactive Example

```bash
ZSH_THEME_CHOICE=mytheme ZSH_THEME_URL="https://example.com/mytheme.zsh-theme" ./bootstrap.sh
```

## Notes

- Some theme screenshots are from other terminals/fonts, so appearance may differ in Git Bash.
- Git branch segment appears only when you are inside a git repository.

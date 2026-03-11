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
- `winget` (optional fallback if direct zsh package install fails)

## Install

From Git Bash in this folder:

```bash
chmod +x bootstrap.sh install_gitbash_ohmyzsh.sh
./bootstrap.sh
```
If zsh download failed with errors
Try run git batch as Admin

```bash
cd "path/to/oh-my-zsh-setup-script"
chmod +x bootstrap.sh install_gitbash_ohmyzsh.sh
./bootstrap.sh
```

Then close and reopen Git Bash.


If `zsh` binary is missing, installer downloads zsh package from internet.
It installs `zsh` into `/usr/bin` when writable, otherwise into `~/.local/gitbash-zsh/bin`.
If needed, installer downloads a temporary `zstd.exe` to unpack the zsh package (no permanent zstd install).
If zsh binary exists but runtime modules are missing, installer repairs runtime files automatically.
If that still fails, it falls back to `winget` Git reinstall.

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


## Notes

- Some theme screenshots are from other terminals/fonts, so appearance may differ in Git Bash.
- Git branch segment appears only when you are inside a git repository.

## Uninstall

From Git Bash in this folder:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

To also remove zsh binaries under `/usr/bin` (advanced):

```bash
./uninstall.sh --remove-system-zsh
```

## Recovery (PowerShell)

If Git Bash cannot open due to a broken zsh auto-start block, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\recover-gitbash.ps1
```

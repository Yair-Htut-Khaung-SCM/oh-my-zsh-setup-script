#!/usr/bin/env bash
set -euo pipefail

REMOVE_SYSTEM_ZSH=0
if [[ "${1:-}" == "--remove-system-zsh" ]]; then
  REMOVE_SYSTEM_ZSH=1
fi

OS_NAME="$(uname -s 2>/dev/null || true)"
case "$OS_NAME" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *)
    echo "This uninstall script is for Git Bash on Windows."
    exit 1
    ;;
esac

echo "[1/5] Removing auto-start block from ~/.bashrc..."
BASHRC="$HOME/.bashrc"
START_MARKER="# >>> auto-start zsh >>>"
END_MARKER="# <<< auto-start zsh <<<"
if [[ -f "$BASHRC" ]]; then
  sed -i "/^${START_MARKER//\//\\/}$/,/^${END_MARKER//\//\\/}$/d" "$BASHRC"
fi

echo "[2/5] Removing Oh My Zsh directory..."
rm -rf "$HOME/.oh-my-zsh"

echo "[3/5] Removing zsh config/history files..."
rm -f "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zlogin" "$HOME/.zlogout" "$HOME/.zshenv" "$HOME/.zsh_history"

shopt -s nullglob
for file in "$HOME"/.zcompdump*; do
  rm -f "$file"
done
shopt -u nullglob

echo "[4/5] Removing local fallback zsh binaries..."
rm -rf "$HOME/.local/gitbash-zsh"

echo "[5/5] Finalizing..."
if [[ "$REMOVE_SYSTEM_ZSH" == "1" ]]; then
  if [[ -w /usr/bin ]]; then
    rm -f /usr/bin/zsh.exe /usr/bin/zsh-*.exe /usr/bin/msys-zsh-*.dll
    echo "Removed /usr/bin zsh binaries (if present)."
  else
    echo "No write access to /usr/bin. Run Git Bash as Administrator and rerun with --remove-system-zsh."
  fi
else
  echo "System zsh binaries in /usr/bin were kept."
  echo "Use --remove-system-zsh if you also want to remove them."
fi

echo "Uninstall complete. Close and reopen Git Bash."

#!/usr/bin/env bash
set -euo pipefail

get_current_theme() {
  local zshrc="$1"
  local current
  current="$(grep -m1 -E '^[[:space:]]*ZSH_THEME="' "$zshrc" | sed -E 's/^[[:space:]]*ZSH_THEME="([^"]+)".*/\1/' || true)"
  if [[ -z "$current" ]]; then
    current="robbyrussell"
  fi
  printf '%s' "$current"
}

theme_exists() {
  local theme="$1"
  if [[ "$theme" == "random" ]]; then
    return 0
  fi
  [[ -f "$HOME/.oh-my-zsh/themes/${theme}.zsh-theme" ]] || [[ -f "$HOME/.oh-my-zsh/custom/themes/${theme}.zsh-theme" ]]
}

normalize_theme_url() {
  local url="$1"
  if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/blob/(.+)$ ]]; then
    printf 'https://raw.githubusercontent.com/%s/%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return
  fi
  printf '%s' "$url"
}

download_theme() {
  local theme="$1"
  local url="$2"
  local normalized_url
  local tmp
  local target_dir
  local target_file

  normalized_url="$(normalize_theme_url "$url")"
  tmp="$(mktemp)"
  target_dir="$HOME/.oh-my-zsh/custom/themes"
  target_file="$target_dir/${theme}.zsh-theme"
  mkdir -p "$target_dir"

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "$normalized_url" -o "$tmp"; then
      rm -f "$tmp"
      return 1
    fi
  else
    if ! wget -qO "$tmp" "$normalized_url"; then
      rm -f "$tmp"
      return 1
    fi
  fi

  if [[ ! -s "$tmp" ]] || grep -qiE '<!doctype html|<html' "$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  mv "$tmp" "$target_file"
  echo "Installed custom theme: $theme" >&2
  return 0
}

download_theme_from_official() {
  local theme="$1"
  local official_url
  official_url="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/themes/${theme}.zsh-theme"
  download_theme "$theme" "$official_url"
}

set_zsh_theme() {
  local zshrc="$1"
  local theme="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v theme="$theme" '
    BEGIN { done=0 }
    /^[[:space:]]*ZSH_THEME=/ {
      if (!done) {
        print "ZSH_THEME=\"" theme "\""
        done=1
      }
      next
    }
    { print }
    END {
      if (!done) {
        print "ZSH_THEME=\"" theme "\""
      }
    }
  ' "$zshrc" > "$tmp"
  mv "$tmp" "$zshrc"
}

select_theme() {
  local zshrc="$1"
  local current_theme
  local selected
  local selected_url
  current_theme="$(get_current_theme "$zshrc")"

  if [[ -n "${ZSH_THEME_CHOICE:-}" ]]; then
    if theme_exists "$ZSH_THEME_CHOICE"; then
      printf '%s' "$ZSH_THEME_CHOICE"
      return
    fi
    if download_theme_from_official "$ZSH_THEME_CHOICE"; then
      printf '%s' "$ZSH_THEME_CHOICE"
      return
    fi
    if [[ -n "${ZSH_THEME_URL:-}" ]] && download_theme "$ZSH_THEME_CHOICE" "$ZSH_THEME_URL"; then
      printf '%s' "$ZSH_THEME_CHOICE"
      return
    fi
    printf 'Theme from ZSH_THEME_CHOICE not found: %s\n' "$ZSH_THEME_CHOICE" >&2
    printf 'Keeping current theme: %s\n' "$current_theme" >&2
    printf '%s' "$current_theme"
    return
  fi

  if [[ ! -t 0 ]]; then
    printf '%s' "$current_theme"
    return
  fi

  while true; do
    echo "Enter Oh My Zsh theme name (examples: robbyrussell, agnoster, bira)." >&2
    echo "Press Enter to keep current: $current_theme" >&2
    echo "Browse themes here: https://github.com/ohmyzsh/ohmyzsh/wiki/Themes" >&2
    read -r -p "Theme: " selected

    case "${selected:-}" in
      "")
        printf '%s' "$current_theme"
        return
        ;;
      *)
        if theme_exists "$selected"; then
          printf '%s' "$selected"
          return
        fi
        if download_theme_from_official "$selected"; then
          printf '%s' "$selected"
          return
        fi
        echo "Theme not found locally: $selected" >&2
        echo "Not available in official Oh My Zsh theme list either." >&2
        echo "Paste direct theme URL to download it, or press Enter to choose again." >&2
        read -r -p "Theme URL: " selected_url
        if [[ -n "${selected_url:-}" ]]; then
          if download_theme "$selected" "$selected_url"; then
            printf '%s' "$selected"
            return
          fi
          echo "Failed to download theme from URL." >&2
        fi
        ;;
    esac
  done
}

echo "[1/6] Checking Git Bash environment..."
OS_NAME="$(uname -s 2>/dev/null || true)"
case "$OS_NAME" in
  MINGW*|MSYS*|CYGWIN*)
    ;;
  *)
    echo "This installer is for Git Bash on Windows."
    echo "Use ./bootstrap.sh for Linux/macOS."
    exit 1
    ;;
esac

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found in PATH."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo "curl or wget is required but neither was found."
  exit 1
fi

echo "[2/6] Ensuring zsh is installed..."
if ! command -v zsh >/dev/null 2>&1; then
  if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm zsh
  else
    echo "zsh is not installed and pacman is unavailable."
    echo "Install zsh first, then rerun this script."
    exit 1
  fi
fi

echo "[3/6] Installing Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  export RUNZSH=no
  export CHSH=no
  export KEEP_ZSHRC=yes

  if command -v curl >/dev/null 2>&1; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
else
  echo "Oh My Zsh already installed."
fi

echo "[4/6] Installing plugins..."
CUSTOM_PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$CUSTOM_PLUGINS_DIR"

if [[ ! -d "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions" ]]; then
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "$CUSTOM_PLUGINS_DIR/zsh-autosuggestions"
else
  echo "Plugin already installed: zsh-autosuggestions"
fi

if [[ ! -d "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting" ]]; then
  git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$CUSTOM_PLUGINS_DIR/zsh-syntax-highlighting"
else
  echo "Plugin already installed: zsh-syntax-highlighting"
fi

ZSHRC="$HOME/.zshrc"
if [[ ! -f "$ZSHRC" ]]; then
  cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
fi

if grep -Eq '^[[:space:]]*plugins=\(' "$ZSHRC"; then
  if ! grep -Eq '^[[:space:]]*plugins=.*\bzsh-autosuggestions\b' "$ZSHRC"; then
    sed -i -E '0,/^[[:space:]]*plugins=\(([^)]*)\)/s//plugins=(\1 zsh-autosuggestions)/' "$ZSHRC"
  fi
  if ! grep -Eq '^[[:space:]]*plugins=.*\bzsh-syntax-highlighting\b' "$ZSHRC"; then
    sed -i -E '0,/^[[:space:]]*plugins=\(([^)]*)\)/s//plugins=(\1 zsh-syntax-highlighting)/' "$ZSHRC"
  fi
else
  printf '\nplugins=(git zsh-autosuggestions zsh-syntax-highlighting)\n' >> "$ZSHRC"
fi

echo "[5/6] Configuring theme..."
CHOSEN_THEME="$(select_theme "$ZSHRC")"
set_zsh_theme "$ZSHRC" "$CHOSEN_THEME"
echo "Theme set to: $CHOSEN_THEME"

BASHRC="$HOME/.bashrc"
START_MARKER="# >>> auto-start zsh >>>"
END_MARKER="# <<< auto-start zsh <<<"
if [[ -f "$BASHRC" ]]; then
  if ! grep -Fq "$START_MARKER" "$BASHRC"; then
    {
      printf '\n%s\n' "$START_MARKER"
      printf 'if [ -z "${ZSH_VERSION-}" ] && [ -t 1 ] && command -v zsh >/dev/null 2>&1; then\n'
      printf '  exec zsh -l\n'
      printf 'fi\n'
      printf '%s\n' "$END_MARKER"
    } >> "$BASHRC"
  fi
else
  {
    printf '%s\n' "$START_MARKER"
    printf 'if [ -z "${ZSH_VERSION-}" ] && [ -t 1 ] && command -v zsh >/dev/null 2>&1; then\n'
    printf '  exec zsh -l\n'
    printf 'fi\n'
    printf '%s\n' "$END_MARKER"
  } > "$BASHRC"
fi

echo "[6/6] Done."
echo "Close and reopen Git Bash. It should start zsh with Oh My Zsh + autosuggestions."
echo "Autosuggestion tip: type part of a past command, then press Right Arrow (->) to accept."

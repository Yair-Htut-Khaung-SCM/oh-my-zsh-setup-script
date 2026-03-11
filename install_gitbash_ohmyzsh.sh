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

resolve_zsh_bin() {
  local candidate
  local win_zsh_path
  local unix_zsh_path

  if [[ -x "/usr/bin/zsh.exe" ]]; then
    printf '%s' "/usr/bin/zsh.exe"
    return 0
  fi

  for candidate in \
    "$HOME/.local/gitbash-zsh/bin/zsh.exe" \
    "/c/Program Files/Git/usr/bin/zsh.exe" \
    "/c/Program Files (x86)/Git/usr/bin/zsh.exe" \
    "/c/Users/${USERNAME:-}/AppData/Local/Programs/Git/usr/bin/zsh.exe"; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  for candidate in \
    "$HOME/.local/gitbash-zsh/bin/zsh-"*.exe \
    /usr/bin/zsh-*.exe \
    "/c/Program Files/Git/usr/bin/zsh-"*.exe \
    "/c/Program Files (x86)/Git/usr/bin/zsh-"*.exe \
    "/c/Users/${USERNAME:-}/AppData/Local/Programs/Git/usr/bin/zsh-"*.exe; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  if command -v where.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    win_zsh_path="$(where.exe zsh.exe 2>/dev/null | tr -d '\r' | sed -n '1p' || true)"
    if [[ -n "$win_zsh_path" ]]; then
      unix_zsh_path="$(cygpath -u "$win_zsh_path" 2>/dev/null || true)"
      if [[ -x "$unix_zsh_path" ]]; then
        printf '%s' "$unix_zsh_path"
        return 0
      fi
    fi

    win_zsh_path="$(where.exe zsh-*.exe 2>/dev/null | tr -d '\r' | sed -n '1p' || true)"
    if [[ -n "$win_zsh_path" ]]; then
      unix_zsh_path="$(cygpath -u "$win_zsh_path" 2>/dev/null || true)"
      if [[ -x "$unix_zsh_path" ]]; then
        printf '%s' "$unix_zsh_path"
        return 0
      fi
    fi
  fi

  if command -v zsh >/dev/null 2>&1; then
    command -v zsh
    return 0
  fi

  return 1
}

resolve_zstd_bin() {
  local candidate
  local win_path
  local unix_path

  if command -v zstd >/dev/null 2>&1; then
    command -v zstd
    return 0
  fi

  for candidate in \
    "/c/Program Files/zstd/zstd.exe" \
    "/c/Program Files (x86)/zstd/zstd.exe" \
    "/c/ProgramData/chocolatey/bin/zstd.exe"; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  if command -v where.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    win_path="$(where.exe zstd.exe 2>/dev/null | tr -d '\r' | sed -n '1p' || true)"
    if [[ -n "$win_path" ]]; then
      unix_path="$(cygpath -u "$win_path" 2>/dev/null || true)"
      if [[ -x "$unix_path" ]]; then
        printf '%s' "$unix_path"
        return 0
      fi
    fi
  fi

  return 1
}

resolve_windows_tar_bin() {
  local win_path
  local unix_path
  local candidate

  if command -v where.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    while IFS= read -r win_path; do
      win_path="${win_path//$'\r'/}"
      case "${win_path,,}" in
        *"\\program files\\git\\usr\\bin\\tar.exe")
          continue
          ;;
      esac
      unix_path="$(cygpath -u "$win_path" 2>/dev/null || true)"
      if [[ -x "$unix_path" ]]; then
        printf '%s' "$unix_path"
        return 0
      fi
    done < <(where.exe tar.exe 2>/dev/null || true)
  fi

  for candidate in \
    "/c/Windows/System32/tar.exe" \
    "/c/WINDOWS/System32/tar.exe" \
    "/c/Windows/Sysnative/tar.exe"; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  return 1
}

ZSTD_TEMP_DIR=""

cleanup_temp_zstd() {
  if [[ -n "$ZSTD_TEMP_DIR" && -d "$ZSTD_TEMP_DIR" ]]; then
    rm -rf "$ZSTD_TEMP_DIR"
  fi
  ZSTD_TEMP_DIR=""
}

download_temp_zstd_bin() {
  local tmp_dir
  local zip_path
  local extract_dir
  local zip_url
  local win_zip
  local win_extract
  local zstd_path

  tmp_dir="$(mktemp -d)"
  zip_path="$tmp_dir/zstd.zip"
  extract_dir="$tmp_dir/extracted"
  mkdir -p "$extract_dir"
  zip_url="https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-v1.5.7-win64.zip"

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL -o "$zip_path" "$zip_url"; then
      rm -rf "$tmp_dir"
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO "$zip_path" "$zip_url"; then
      rm -rf "$tmp_dir"
      return 1
    fi
  else
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! command -v powershell.exe >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 1
  fi

  if command -v cygpath >/dev/null 2>&1; then
    win_zip="$(cygpath -w "$zip_path")"
    win_extract="$(cygpath -w "$extract_dir")"
  else
    win_zip="$zip_path"
    win_extract="$extract_dir"
  fi

  if ! powershell.exe -NoProfile -Command "Expand-Archive -Path '$win_zip' -DestinationPath '$win_extract' -Force" >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 1
  fi

  zstd_path="$(ls "$extract_dir"/zstd-*/zstd.exe "$extract_dir"/zstd-*/*/zstd.exe 2>/dev/null | head -n 1 || true)"
  if [[ -z "$zstd_path" || ! -x "$zstd_path" ]]; then
    rm -rf "$tmp_dir"
    return 1
  fi

  ZSTD_TEMP_DIR="$tmp_dir"
  printf '%s' "$zstd_path"
  return 0
}

ensure_zstd_decompressor() {
  local zstd_bin
  zstd_bin="$(resolve_zstd_bin || true)"
  if [[ -n "$zstd_bin" ]]; then
    if "$zstd_bin" --version >/dev/null 2>&1 || "$zstd_bin" -V >/dev/null 2>&1; then
      printf '%s' "$zstd_bin"
      return 0
    fi
  fi

  echo "zstd not found. Downloading temporary decompressor..." >&2
  zstd_bin="$(download_temp_zstd_bin || true)"
  if [[ -n "$zstd_bin" ]]; then
    if "$zstd_bin" --version >/dev/null 2>&1 || "$zstd_bin" -V >/dev/null 2>&1; then
      printf '%s' "$zstd_bin"
      return 0
    fi
  fi

  return 1
}

install_zsh_from_msys_repo() {
  local base_url
  local index_html
  local pkg_name
  local tmp_pkg
  local tmp_tar
  local tmp_dir
  local target_prefix
  local zsh_exe
  local zsh_ver_exe
  local zstd_bin
  local win_tar_bin

  base_url="https://repo.msys2.org/msys/x86_64/"
  echo "zsh is missing. Downloading zsh package from internet..."

  if command -v curl >/dev/null 2>&1; then
    if ! index_html="$(curl -fsSL "$base_url")"; then
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! index_html="$(wget -qO- "$base_url")"; then
      return 1
    fi
  else
    return 1
  fi

  pkg_name="$(printf '%s' "$index_html" | tr '"' '\n' | grep -E '^zsh-[0-9].*-x86_64\.pkg\.tar\.zst$' | sort -V | tail -n 1)"
  if [[ -z "$pkg_name" ]]; then
    return 1
  fi

  tmp_pkg="$(mktemp -u)"
  tmp_pkg="${tmp_pkg}.pkg.tar.zst"

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL -o "$tmp_pkg" "${base_url}${pkg_name}"; then
      rm -f "$tmp_pkg"
      return 1
    fi
  else
    if ! wget -qO "$tmp_pkg" "${base_url}${pkg_name}"; then
      rm -f "$tmp_pkg"
      return 1
    fi
  fi

  tmp_dir="$(mktemp -d)"
  win_tar_bin="$(resolve_windows_tar_bin || true)"
  if [[ -n "$win_tar_bin" ]]; then
    if ! "$win_tar_bin" -xf "$tmp_pkg" -C "$tmp_dir"; then
      rm -f "$tmp_pkg"
      rm -rf "$tmp_dir"
      return 1
    fi
  else
    zstd_bin="$(ensure_zstd_decompressor || true)"
    if [[ -z "$zstd_bin" ]]; then
      rm -f "$tmp_pkg"
      rm -rf "$tmp_dir"
      return 1
    fi

    tmp_tar="${tmp_pkg%.zst}"
    if ! "$zstd_bin" -d -c "$tmp_pkg" > "$tmp_tar"; then
      rm -f "$tmp_pkg" "$tmp_tar"
      rm -rf "$tmp_dir"
      cleanup_temp_zstd
      return 1
    fi

    if ! tar -xf "$tmp_tar" -C "$tmp_dir"; then
      rm -f "$tmp_pkg" "$tmp_tar"
      rm -rf "$tmp_dir"
      cleanup_temp_zstd
      return 1
    fi

    rm -f "$tmp_tar"
    cleanup_temp_zstd
  fi

  zsh_exe="$tmp_dir/usr/bin/zsh.exe"
  zsh_ver_exe="$(ls "$tmp_dir"/usr/bin/zsh-*.exe 2>/dev/null | head -n 1 || true)"
  if [[ ! -x "$zsh_exe" && -z "$zsh_ver_exe" ]]; then
    rm -f "$tmp_pkg"
    rm -rf "$tmp_dir"
    return 1
  fi

  if [[ -w /usr/bin && -w /usr/lib && -w /usr/share ]]; then
    target_prefix="/usr"
  else
    target_prefix="$HOME/.local/gitbash-zsh"
  fi

  mkdir -p "$target_prefix/bin" "$target_prefix/lib" "$target_prefix/share"

  cp -f "$tmp_dir"/usr/bin/zsh*.exe "$target_prefix/bin/" 2>/dev/null || true
  cp -f "$tmp_dir"/usr/bin/msys-zsh-*.dll "$target_prefix/bin/" 2>/dev/null || true

  if [[ -d "$tmp_dir/usr/lib/zsh" ]]; then
    cp -R "$tmp_dir/usr/lib/zsh" "$target_prefix/lib/" 2>/dev/null || true
  fi

  if [[ -d "$tmp_dir/usr/share/zsh" ]]; then
    cp -R "$tmp_dir/usr/share/zsh" "$target_prefix/share/" 2>/dev/null || true
  fi

  if [[ "$target_prefix" != "/usr" && -d "$tmp_dir/etc/zsh" ]]; then
    mkdir -p "$target_prefix/etc"
    cp -R "$tmp_dir/etc/zsh" "$target_prefix/etc/" 2>/dev/null || true
  fi

  rm -f "$tmp_pkg"
  rm -rf "$tmp_dir"
  hash -r
  return 0
}

zsh_runtime_files_ok() {
  local zsh_bin="$1"

  if [[ "$zsh_bin" == "$HOME/.local/gitbash-zsh/bin/"* ]]; then
    [[ -d "$HOME/.local/gitbash-zsh/lib/zsh" && -d "$HOME/.local/gitbash-zsh/share/zsh/functions" ]]
    return $?
  fi

  [[ -d "/usr/lib/zsh" && -d "/usr/share/zsh/functions" ]]
}

ensure_local_zsh_runtime_block() {
  local zshrc="$1"
  local start_marker
  local end_marker
  local block
  local tmp
  local inserted
  local line

  start_marker="# >>> local zsh runtime >>>"
  end_marker="# <<< local zsh runtime <<<"
  block="$(cat <<'EOF'
# >>> local zsh runtime >>>
if [[ -d "$HOME/.local/gitbash-zsh/lib/zsh" ]]; then
  typeset -a _local_mod_paths
  for _local_mod_dir in "$HOME"/.local/gitbash-zsh/lib/zsh/*/zsh; do
    [[ -d "$_local_mod_dir" ]] && _local_mod_paths+=("$_local_mod_dir")
  done
  if (( ${#_local_mod_paths[@]} )); then
    module_path=("${_local_mod_paths[@]}" "${module_path[@]}")
  fi
fi
if [[ -d "$HOME/.local/gitbash-zsh/share/zsh/functions" ]]; then
  fpath=("$HOME/.local/gitbash-zsh/share/zsh/functions" "$HOME/.local/gitbash-zsh/share/zsh/site-functions" "${fpath[@]}")
fi
unset _local_mod_dir _local_mod_paths
# <<< local zsh runtime <<<
EOF
)"

  if [[ -f "$zshrc" ]]; then
    sed -i "/^${start_marker//\//\\/}$/,/^${end_marker//\//\\/}$/d" "$zshrc"
  fi

  tmp="$(mktemp)"
  inserted=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$inserted" == "0" && "$line" == *"oh-my-zsh.sh"* ]]; then
      printf '%s\n' "$block" >> "$tmp"
      inserted=1
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$zshrc"

  if [[ "$inserted" == "0" ]]; then
    printf '\n%s\n' "$block" >> "$tmp"
  fi

  mv "$tmp" "$zshrc"
}

install_zsh_if_missing() {
  local existing_zsh_bin
  existing_zsh_bin="$(resolve_zsh_bin || true)"
  if [[ -n "$existing_zsh_bin" ]]; then
    if zsh_runtime_files_ok "$existing_zsh_bin"; then
      return 0
    fi
    echo "zsh binary found, but runtime files are missing. Repairing zsh runtime..."
  fi

  if install_zsh_from_msys_repo && resolve_zsh_bin >/dev/null 2>&1; then
    return 0
  fi

  run_with_timeout() {
    local seconds="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
      timeout "$seconds" "$@"
    else
      "$@"
    fi
  }

  if command -v winget.exe >/dev/null 2>&1 || command -v winget >/dev/null 2>&1; then
    echo "Direct zsh package install failed. Trying Git installer fallback..."
    local winget_cmd
    if command -v winget.exe >/dev/null 2>&1; then
      winget_cmd="winget.exe"
    else
      winget_cmd="winget"
    fi

    run_with_timeout 900 "$winget_cmd" install --id Git.Git -e --force --silent --disable-interactivity --accept-package-agreements --accept-source-agreements || true
    if resolve_zsh_bin >/dev/null 2>&1; then
      return 0
    fi

    echo "Install command finished, but zsh is still not visible in this shell."
    echo "Close all Git Bash windows, open a new one, and run ./bootstrap.sh again."
    echo "If it still fails, run this manually in PowerShell as Administrator:"
    echo "  winget install --id Git.Git -e --force --accept-package-agreements --accept-source-agreements"
    return 1
  fi

  echo "winget not found, so zsh cannot be downloaded automatically."
  echo "Install Git for Windows from internet, then rerun ./bootstrap.sh."
  return 1
}

zsh_runtime_healthy() {
  local zsh_bin="$1"
  "$zsh_bin" -fc 'zmodload zsh/zle >/dev/null 2>&1 && zmodload zsh/parameter >/dev/null 2>&1 && zmodload zsh/datetime >/dev/null 2>&1'
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
if ! install_zsh_if_missing; then
  exit 1
fi

ZSH_BIN="$(resolve_zsh_bin || true)"
if [[ -z "$ZSH_BIN" ]]; then
  echo "zsh install step finished but no zsh binary was found."
  exit 1
fi

if [[ "$ZSH_BIN" == *zsh-*.exe ]]; then
  echo "Using versioned zsh binary: $ZSH_BIN"
fi

echo "[3/6] Installing Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
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

ensure_local_zsh_runtime_block "$ZSHRC"

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
  sed -i "/^${START_MARKER//\//\\/}$/,/^${END_MARKER//\//\\/}$/d" "$BASHRC"
fi

AUTO_START_ZSH="${AUTO_START_ZSH:-1}"
if [[ "$AUTO_START_ZSH" == "1" ]]; then
  if zsh_runtime_healthy "$ZSH_BIN"; then
    if [[ -f "$BASHRC" ]]; then
      {
        printf '\n%s\n' "$START_MARKER"
        printf 'if ! command -v zsh >/dev/null 2>&1 && [ -x "%s" ]; then\n' "$ZSH_BIN"
        printf '  alias zsh="%s"\n' "$ZSH_BIN"
        printf 'fi\n'
        printf 'if [ -z "${ZSH_VERSION-}" ] && [ -t 1 ] && [ -x "%s" ]; then\n' "$ZSH_BIN"
        printf '  exec "%s"\n' "$ZSH_BIN"
        printf 'fi\n'
        printf '%s\n' "$END_MARKER"
      } >> "$BASHRC"
    else
      {
        printf '%s\n' "$START_MARKER"
        printf 'if ! command -v zsh >/dev/null 2>&1 && [ -x "%s" ]; then\n' "$ZSH_BIN"
        printf '  alias zsh="%s"\n' "$ZSH_BIN"
        printf 'fi\n'
        printf 'if [ -z "${ZSH_VERSION-}" ] && [ -t 1 ] && [ -x "%s" ]; then\n' "$ZSH_BIN"
        printf '  exec "%s"\n' "$ZSH_BIN"
        printf 'fi\n'
        printf '%s\n' "$END_MARKER"
      } > "$BASHRC"
    fi
  else
    echo "Skipping auto-start zsh block: runtime modules failed validation."
    echo "You can still run zsh manually after fixing runtime files."
  fi
else
  echo "AUTO_START_ZSH=0: leaving Git Bash startup unchanged."
fi

echo "[6/6] Done."
echo "Close and reopen Git Bash. It should start zsh with Oh My Zsh + autosuggestions."
echo "Autosuggestion tip: type part of a past command, then press Right Arrow (->) to accept."

#!/usr/bin/env bash
set -euo pipefail

OS_NAME="$(uname -s 2>/dev/null || true)"
case "$OS_NAME" in
  MINGW*|MSYS*|CYGWIN*)
    echo "Git Bash on Windows detected."
    bash ./install_gitbash_ohmyzsh.sh
    exit $?
    ;;
esac

echo "This bootstrap is for Git Bash on Windows only."
echo "Open Git Bash and run: ./bootstrap.sh"
exit 1

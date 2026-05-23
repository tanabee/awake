#!/usr/bin/env bash
# Installer for `awake`.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tanabee/awake/main/install.sh | bash
#
# What it does:
#   1. Clones (or updates) the awake repo into $AWAKE_HOME (default ~/.local/share/awake).
#   2. Symlinks $AWAKE_HOME/bin/awake into $BIN_DIR (default ~/.local/bin/awake).
#   3. Warns if $BIN_DIR is not on PATH.

set -euo pipefail

REPO_URL="${AWAKE_REPO_URL:-https://github.com/tanabee/awake.git}"
AWAKE_HOME="${AWAKE_HOME:-$HOME/.local/share/awake}"
BIN_DIR="${AWAKE_BIN_DIR:-$HOME/.local/bin}"
LINK_PATH="$BIN_DIR/awake"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "awake: macOS only" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "awake: git is required" >&2
  exit 1
fi

mkdir -p "$BIN_DIR"

if [[ -d "$AWAKE_HOME/.git" ]]; then
  echo "==> Updating awake in $AWAKE_HOME"
  git -C "$AWAKE_HOME" pull --ff-only
else
  echo "==> Cloning awake into $AWAKE_HOME"
  mkdir -p "$(dirname "$AWAKE_HOME")"
  git clone "$REPO_URL" "$AWAKE_HOME"
fi

TARGET="$AWAKE_HOME/bin/awake"
if [[ ! -x "$TARGET" ]]; then
  chmod +x "$TARGET" 2>/dev/null || true
fi

if [[ -L "$LINK_PATH" || -e "$LINK_PATH" ]]; then
  current="$(readlink "$LINK_PATH" 2>/dev/null || true)"
  if [[ "$current" != "$TARGET" ]]; then
    echo "==> Replacing existing $LINK_PATH"
    rm -f "$LINK_PATH"
    ln -s "$TARGET" "$LINK_PATH"
  fi
else
  echo "==> Linking $LINK_PATH -> $TARGET"
  ln -s "$TARGET" "$LINK_PATH"
fi

case ":$PATH:" in
  *":$BIN_DIR:"*)
    ;;
  *)
    echo ""
    echo "Warning: $BIN_DIR is not on your PATH."
    echo "Add this to your shell profile (e.g. ~/.zshrc):"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo ""
echo "Installed. Run: awake --help"

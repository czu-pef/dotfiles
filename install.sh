#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$HOME/code/bin"

if ! command -v php >/dev/null 2>&1; then
  echo "php is required but not installed" >&2
  exit 1
fi

mkdir -p "$BIN_DIR"

export TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

EXPECTED_SIG="$(curl -fsSL https://composer.github.io/installer.sig)"
curl -fsSL https://getcomposer.org/installer -o "$TMP_DIR/composer-setup.php"
ACTUAL_SIG="$(php -r "echo hash_file('sha384', getenv('TMP_DIR') . '/composer-setup.php');")"

if [ "$EXPECTED_SIG" != "$ACTUAL_SIG" ]; then
  echo "Installer checksum mismatch, aborting" >&2
  exit 1
fi

php "$TMP_DIR/composer-setup.php" --install-dir="$BIN_DIR" --filename=composer

echo "Composer installed at $BIN_DIR/composer"
echo "Add it to your PATH with: export PATH=\"\$HOME/code/bin:\$PATH\""

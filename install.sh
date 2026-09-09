#!/usr/bin/env bash
#
# Bootstrap a cPanel account for running Laravel apps.
#
#   curl -fsSL https://raw.githubusercontent.com/czu-pef/dotfiles/main/install.sh | bash
#
# 1. Finds a PHP 8.4+ binary and checks the extensions Laravel needs.
#    Missing ones pause the script with instructions on what to enable; the
#    check can be skipped at the prompt, or with SKIP_EXTENSION_CHECK=1.
# 2. Creates ~/code/{bin,dotfiles,stage1} if missing.
# 3. Clones (or updates) the dotfiles into ~/code/dotfiles.
# 4. Installs Composer into ~/code/bin.

set -euo pipefail

CODE_DIR="$HOME/code"
BIN_DIR="$CODE_DIR/bin"
DOTFILES_DIR="$CODE_DIR/dotfiles"
REPO_URL="https://github.com/czu-pef/dotfiles.git"
MIN_PHP="8.4"

# Laravel will not boot without these. pdo_mysql/mysqli cover the database,
# sockets covers Reverb/websockets and anything talking raw TCP.
REQUIRED_EXTENSIONS=(
  ctype curl dom fileinfo filter hash mbstring mysqli openssl pcre pdo
  pdo_mysql session sockets tokenizer xml zip
)

# Not fatal, but almost always wanted (queues, images, money maths, i18n).
RECOMMENDED_EXTENSIONS=(bcmath exif gd iconv intl opcache pcntl posix sodium)

RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RESET="\033[m"

TMP_DIRS=""
trap 'for d in $TMP_DIRS; do rm -rf "$d"; done' EXIT

info()  { echo -e "${GREEN}==>${RESET} $*"; }
warn()  { echo -e "${YELLOW}==>${RESET} $*"; }
error() { echo -e "${RED}==>${RESET} $*" >&2; }

# Reads from the terminal rather than stdin, so prompts still work when this
# script arrives through a pipe (curl ... | bash). The question is written to
# /dev/tty rather than passed to `read -p`, whose prompt goes to stderr and so
# vanishes for any caller that silences it; stdout is no good either, since
# every caller runs this in a command substitution and would capture it.
prompt() {
  local reply
  printf '%s' "$1" > /dev/tty 2>/dev/null || return 1
  read -r reply < /dev/tty 2>/dev/null || return 1
  echo "$reply"
}

# --- PHP -------------------------------------------------------------------

# Every place cPanel/CloudLinux hides a PHP binary, newest first.
PHP_CANDIDATES=(
  /opt/alt/php85/usr/bin/php
  /opt/alt/php84/usr/bin/php
  /opt/cpanel/ea-php85/root/usr/bin/php
  /opt/cpanel/ea-php84/root/usr/bin/php
)

php_version() {
  "$1" -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null || true
}

# True when $1 >= $2, comparing as dotted versions.
version_at_least() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# A plain loop rather than a pipe or process substitution: CageFS accounts
# often have no /dev/fd, which is what `< <(...)` needs, and a pipe would put
# the assignment in a subshell.
find_php() {
  local candidate version
  for candidate in "${PHP_CANDIDATES[@]}" "$(command -v php 2>/dev/null || true)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    version="$(php_version "$candidate")"
    [ -n "$version" ] || continue
    if version_at_least "$version" "$MIN_PHP"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# How to enable extensions depends on which PHP stack the account is on.
enable_instructions() {
  local php_bin="$1"
  case "$php_bin" in
    /opt/alt/*)
      echo "  cPanel -> Software -> Select PHP Version -> Extensions tab"
      echo "  Tick the extensions listed above, changes save automatically."
      ;;
    /opt/cpanel/ea-php*)
      echo "  EasyApache PHP extensions are server-wide and need WHM/root access."
      echo "  Ask your host to enable the extensions listed above for $(basename "$(dirname "$(dirname "$php_bin")")")."
      ;;
    *)
      echo "  cPanel -> Software -> Select PHP Version -> Extensions tab,"
      echo "  or ask your host to enable the extensions listed above."
      ;;
  esac
}

# Echoes the extensions from $2.. that $1 does not have loaded, space separated.
missing_extensions() {
  local php_bin="$1"; shift
  local loaded extension missing=""
  loaded="$("$php_bin" -m 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  for extension in "$@"; do
    printf '%s\n' "$loaded" | grep -qx "$extension" || missing="$missing $extension"
  done
  echo "${missing# }"
}

check_php() {
  local php_bin missing recommended reply skipped=""

  if ! php_bin="$(find_php)"; then
    error "No PHP $MIN_PHP or newer found."
    echo
    echo "Enable it first:"
    echo "  cPanel -> Software -> Select PHP Version -> pick PHP $MIN_PHP"
    echo
    echo "Then re-run this script."
    exit 1
  fi

  PHP_BIN="$php_bin"
  info "Using PHP $(php_version "$PHP_BIN") at $PHP_BIN"

  while :; do
    missing="$(missing_extensions "$PHP_BIN" "${REQUIRED_EXTENSIONS[@]}")"
    [ -z "$missing" ] && break

    # An escape hatch for a run with no terminal to prompt on, or when the
    # missing extensions are known to be irrelevant to what is being deployed.
    if [ -n "${SKIP_EXTENSION_CHECK:-}" ]; then
      skipped=1
      break
    fi

    error "Missing required PHP extensions: $missing"
    echo
    enable_instructions "$PHP_BIN"
    echo

    if ! reply="$(prompt 'Press Enter once enabled to re-check, s to skip, or q to quit: ')"; then
      error "No terminal available to wait on. Enable the extensions, then re-run."
      error "Set SKIP_EXTENSION_CHECK=1 to carry on without them."
      exit 1
    fi
    case "$reply" in
      q | Q | quit) exit 1 ;;
      s | S | skip) skipped=1; break ;;
    esac
  done

  if [ -n "$skipped" ]; then
    warn "Carrying on without: $missing"
    warn "Laravel will not boot until they are enabled."
  else
    info "All required extensions are enabled."
  fi

  recommended="$(missing_extensions "$PHP_BIN" "${RECOMMENDED_EXTENSIONS[@]}")"
  if [ -n "$recommended" ]; then
    warn "Optional extensions not enabled: $recommended"
    enable_instructions "$PHP_BIN"
  fi
}

# --- Directories -----------------------------------------------------------

create_directories() {
  local dir
  for dir in "$BIN_DIR" "$DOTFILES_DIR" "$CODE_DIR/stage1"; do
    if [ -d "$dir" ]; then
      info "$dir already exists"
    else
      mkdir -p "$dir"
      info "Created $dir"
    fi
  done
}

# --- Dotfiles --------------------------------------------------------------

# Cloned over HTTPS: a fresh cPanel account has no SSH key on GitHub, and this
# checkout only ever needs to be pulled.
install_dotfiles() {
  if ! command -v git >/dev/null 2>&1; then
    warn "git not found, skipping the dotfiles checkout."
    warn "Install git or upload the files by hand, then re-run."
    return
  fi

  if [ -d "$DOTFILES_DIR/.git" ]; then
    info "Updating the dotfiles in $DOTFILES_DIR"
    if ! git -C "$DOTFILES_DIR" pull --ff-only --quiet; then
      warn "Could not fast-forward $DOTFILES_DIR, pull it by hand."
    fi
    return
  fi

  # A non-empty directory that is not a checkout holds something we did not
  # put there, so leave it be rather than clobber it.
  if [ -n "$(ls -A "$DOTFILES_DIR" 2>/dev/null)" ]; then
    warn "$DOTFILES_DIR is not empty and not a git checkout, leaving it alone."
    warn "Move it aside and re-run to get the dotfiles."
    return
  fi

  info "Cloning the dotfiles into $DOTFILES_DIR"
  git clone --quiet "$REPO_URL" "$DOTFILES_DIR"
}

# --- Hostname --------------------------------------------------------------

# Echoes the name currently in .hostname, empty if the file is missing or the
# name is still blank. Sourced in a subshell so it cannot leak into this one.
read_hostname() {
  local file="$DOTFILES_DIR/.hostname"
  [ -f "$file" ] || return 0
  ( set +u; . "$file" 2>/dev/null; echo "${DOTFILES_HOSTNAME:-}" )
}

# Every shell sources .hostname, so only accept a name that cannot turn into
# something else once it is quoted into the file.
valid_hostname() {
  case "$1" in
    "" | *[!A-Za-z0-9._-]*) return 1 ;;
  esac
}

write_hostname() {
  cat > "$DOTFILES_DIR/.hostname" <<EOF
# Machine name shown in the shell prompt. Set it per machine.
DOTFILES_HOSTNAME="$1"
EOF
}

configure_hostname() {
  local existing default reply

  # Without a checkout there is nothing to write the name into.
  [ -f "$DOTFILES_DIR/.bashrc" ] || return

  existing="$(read_hostname)"
  default="${existing:-${USER:-$(id -un 2>/dev/null || echo unknown)}}"

  while :; do
    if ! reply="$(prompt "Name this machine for the shell prompt [$default]: ")"; then
      warn "No terminal available to ask for a name."
      warn "Set it by hand in $DOTFILES_DIR/.hostname"
      return
    fi

    reply="${reply:-$default}"
    valid_hostname "$reply" && break

    error "Use letters, digits, dots, dashes or underscores only."
  done

  if [ "$reply" = "$existing" ]; then
    info "Prompt name left as \"$existing\""
    return
  fi

  write_hostname "$reply"
  info "Prompt name set to \"$reply\" in $DOTFILES_DIR/.hostname"
}

# --- Composer --------------------------------------------------------------

install_composer() {
  local tmp_dir expected_sig actual_sig

  tmp_dir="$(mktemp -d)"
  TMP_DIRS="$TMP_DIRS $tmp_dir"

  expected_sig="$(curl -fsSL https://composer.github.io/installer.sig)"
  curl -fsSL https://getcomposer.org/installer -o "$tmp_dir/composer-setup.php"
  actual_sig="$("$PHP_BIN" -r "echo hash_file('sha384', '$tmp_dir/composer-setup.php');")"

  if [ "$expected_sig" != "$actual_sig" ]; then
    error "Composer installer checksum mismatch, aborting"
    exit 1
  fi

  "$PHP_BIN" "$tmp_dir/composer-setup.php" \
    --quiet --install-dir="$BIN_DIR" --filename=composer.phar

  # Wrapper so composer always runs on the PHP we verified above, whatever
  # version happens to be first on $PATH.
  cat > "$BIN_DIR/composer" <<EOF
#!/usr/bin/env bash
exec "$PHP_BIN" "$BIN_DIR/composer.phar" "\$@"
EOF
  chmod +x "$BIN_DIR/composer"

  info "Installed Composer $("$BIN_DIR/composer" --version --no-ansi 2>/dev/null | awk '{print $3}') at $BIN_DIR/composer"
}

# --- Shell wiring ----------------------------------------------------------

# An SSH session is a login shell, and login shells read ~/.bash_profile and
# never ~/.bashrc, so the profile has to hand over. Bash reads only the first
# of these three that exists.
check_bash_profile() {
  local profile
  for profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    [ -f "$profile" ] || continue
    if ! grep -qs '\.bashrc' "$profile"; then
      echo
      warn "$profile does not source ~/.bashrc, so SSH logins will skip it."
      echo "  Hand over with:"
      echo "    echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> $profile"
    fi
    return
  done

  echo
  warn "No ~/.bash_profile, so SSH logins will not read ~/.bashrc. Create it with:"
  echo "  echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.bash_profile"
}

# --- Run -------------------------------------------------------------------

check_php
create_directories
install_dotfiles
configure_hostname
install_composer

echo
info "Done."
echo

if [ ! -f "$DOTFILES_DIR/.bashrc" ]; then
  # No checkout, so nothing sets up PATH for us.
  echo "The dotfiles are not in place. Put Composer on your PATH with:"
  echo "  export PATH=\"\$HOME/code/bin:\$PATH\""
elif grep -qs 'code/dotfiles/\.bashrc' "$HOME/.bashrc"; then
  echo "~/.bashrc already sources the dotfiles. Pick up any changes with:"
  echo "  source ~/.bashrc"
else
  echo "Source the dotfiles from your ~/.bashrc:"
  echo "  echo 'source ~/code/dotfiles/.bashrc' >> ~/.bashrc"
  echo "  source ~/.bashrc"
  echo
  echo "That loads the aliases and puts ~/code/bin (Composer) on your PATH."
fi

if [ -f "$DOTFILES_DIR/.bashrc" ]; then
  if [ -z "$(read_hostname)" ]; then
    echo
    echo "Then name this machine for the shell prompt:"
    echo "  vi ~/code/dotfiles/.hostname   # set DOTFILES_HOSTNAME"
  fi

  check_bash_profile
fi

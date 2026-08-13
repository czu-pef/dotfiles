# dotfiles

Bash configuration and a bootstrap script for running Laravel apps on cPanel
hosting.

## Install

On a new (or existing) cPanel account, over SSH:

```sh
curl -fsSL https://raw.githubusercontent.com/czu-pef/dotfiles/main/install.sh | bash
```

Then source the dotfiles from your `~/.bashrc`, as the script will remind you:

```sh
echo 'source ~/code/dotfiles/.bashrc' >> ~/.bashrc
source ~/.bashrc
```

An SSH session is a login shell, and login shells read `~/.bash_profile` rather
than `~/.bashrc`, so the profile has to hand over. Most accounts already do; the
install script checks and tells you if yours does not:

```sh
echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.bash_profile
```

The install script asks for the machine name shown in the prompt and writes it to
`~/code/dotfiles/.hostname`, defaulting to the account name:

```sh
Name this machine for the shell prompt [cpaneluser]: stage1
```

Re-run the script to change it later; the current name becomes the default, so
pressing Enter keeps it. Editing the file by hand works just as well:

```sh
DOTFILES_HOSTNAME="stage1"
```

Re-running the install script is safe: it updates the checkout, leaves existing
directories alone, keeps the machine name unless you type a new one, and
reinstalls Composer at the current version.

## What install.sh does

1. **Finds PHP 8.4 or newer.** It looks in the places cPanel and CloudLinux keep
   PHP (`/opt/alt/php84`, `/opt/cpanel/ea-php84`, …) before falling back to
   whatever is on `$PATH`. If there is no suitable binary, it tells you to pick
   PHP 8.4 in *cPanel → Software → Select PHP Version* and stops.
2. **Checks the PHP extensions Laravel needs**, including `pdo_mysql` and
   `mysqli` for MySQL. Anything missing is listed with instructions for enabling
   it, and the script waits: enable the extensions in cPanel in another tab,
   press Enter, and it re-checks. Extensions that are merely nice to have
   (`bcmath`, `gd`, `intl`, `opcache`, …) only produce a warning.
3. **Creates `~/code/bin`, `~/code/dotfiles` and `~/code/stage1`** if they do
   not exist.
4. **Clones this repo into `~/code/dotfiles`**, or fast-forwards it if it is
   already a checkout. A non-empty directory that is not a checkout is left
   untouched.
5. **Asks for the machine name** shown in the shell prompt and writes
   `.hostname`. It defaults to the current name, or the account name on a fresh
   install, and only accepts letters, digits, dots, dashes and underscores,
   since every shell sources that file.
6. **Installs Composer into `~/code/bin`**, verifying the installer checksum
   first.

Composer is installed as `composer.phar` alongside a small `composer` wrapper
that pins it to the PHP 8.4 binary found in step 1. Without that, the phar's
`#!/usr/bin/env php` shebang would pick up whatever PHP comes first on `$PATH`,
which on shared hosting is often still 7.x.

Where extensions are enabled depends on the PHP stack. On CloudLinux
(`/opt/alt/php84`) you control them yourself in *Select PHP Version → Extensions*.
On EasyApache (`/opt/cpanel/ea-php84`) they are server-wide and need root, so the
script tells you to ask your host.

## What is in here

| File | Contents |
| --- | --- |
| `.bashrc` | Sources everything below, sets `$PATH` (`~/code/bin`, alt-nodejs 22) and the git-aware prompt |
| `.hostname.stub` | Template copied to `.hostname` on first run; holds the per-machine prompt name |
| `.aliases_git` | `gs`, `gaac`, `gl`, `amend`, `nah`, `wip`, … |
| `.aliases_filesystem` | `..`, `ll`, `la`, `take` |
| `.aliases_laravel` | `art`, `t`, `tf`, `seed`, `pu`, … |
| `.aliases_czu` | Project shortcuts (`prod`, `dev`) |
| `.vimrc` | Syntax highlighting, `jj` to escape, sane search defaults |
| `install.sh` | The bootstrap script described above |

`.hostname` is generated per machine and is not tracked, so the prompt shows
which host you are on. `install.sh` asks for the name and writes the file;
`.bashrc` falls back to creating it from `.hostname.stub` the first time it is
sourced and warns until it is filled in.

## Local development

The dotfiles are shared between machines, so `install.sh` is written for cPanel
but does nothing macOS-specific either. To try changes without touching your
real setup, run it against a throwaway home directory:

```sh
HOME=/tmp/fakehome bash install.sh
```

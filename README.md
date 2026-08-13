# dotfiles

Bash configuration and a bootstrap script for running Laravel apps on cPanel
hosting.

## Install

On a new (or existing) cPanel account, over SSH:

```sh
curl -fsSL https://raw.githubusercontent.com/vitnasinec/dotfiles/main/install.sh | bash
```

Then source the dotfiles from your `~/.bashrc`, as the script will remind you:

```sh
echo 'source ~/code/dotfiles/.bashrc' >> ~/.bashrc
source ~/.bashrc
```

Finally, set the machine name shown in the prompt by editing
`~/code/dotfiles/.hostname`:

```sh
DOTFILES_HOSTNAME="stage1"
```

Re-running the install script is safe: it updates the checkout, leaves existing
directories alone, and reinstalls Composer at the current version.

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
5. **Installs Composer into `~/code/bin`**, verifying the installer checksum
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
which host you are on. `.bashrc` creates it from `.hostname.stub` the first time
it is sourced and warns until you fill it in.

## Local development

The dotfiles are shared between machines, so `install.sh` is written for cPanel
but does nothing macOS-specific either. To try changes without touching your
real setup, run it against a throwaway home directory:

```sh
HOME=/tmp/fakehome bash install.sh
```

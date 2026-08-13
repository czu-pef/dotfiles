# Working on this repo

## Never run anything on this machine

The scripts here target **cPanel accounts only**. Do not execute `install.sh`,
`.bashrc`, or any other file in this repo locally — not to "smoke test" it, not
against a throwaway `HOME`, not a snippet extracted from it, not to check that a
function returns something plausible.

A local run tells you nothing. This machine is macOS with Herd; the target is a
CloudLinux/CageFS account reached over SSH. The two disagree on exactly the
things these scripts care about — which PHP exists and where, what `/dev` holds,
which shell built-ins behave. A green result here is not evidence, and a result
mentioning Herd, Homebrew, `/opt/homebrew`, or `/Users/...` is noise.

Static checks that parse without executing are fine and encouraged:
`bash -n install.sh`, `shellcheck install.sh`, reading the code.

To verify actual behaviour, hand the user a command to paste into their cPanel
SSH session and wait for what it prints. Their box is the only authority.

## The target environment

Assume every one of these when reasoning about a change:

- **CloudLinux CageFS.** `/dev/fd` is frequently absent, so process
  substitution (`< <(cmd)`) and anything else relying on `/dev/fd` fails with
  `/dev/fd/63: No such file or directory`. This has bitten `install.sh` before.
  Prefer plain loops over arrays; a pipe into `while` also works but puts the
  body in a subshell, so assignments are lost.
- **Piped into bash.** The documented install is
  `curl -fsSL .../install.sh | bash`, so the script is read from stdin. Bash
  names it `main` in error messages, `$0` is useless, and stdin is the pipe —
  which is why prompts read from `/dev/tty`.
- **PHP lives in odd places.** `/opt/alt/phpXX/usr/bin/php` (CloudLinux) or
  `/opt/cpanel/ea-phpXX/root/usr/bin/php` (EasyApache), often with an ancient
  PHP first on `$PATH`. Never assume `php` is the right one.
- **GNU coreutils.** `sort -V`, `grep -qx` and friends are available. Do not
  contort the code for BSD/macOS tool differences; they are irrelevant here.
- **Login shells read `~/.bash_profile`, not `~/.bashrc`**, so the handover
  matters.

## Shipping a fix

The install URL serves `main` from GitHub, so a fix is not live until it is
committed and pushed to `main`. Do that when asked, then tell the user to re-run
the curl one-liner on the box.

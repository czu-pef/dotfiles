MAGENTA="\033[1;31m"
ORANGE="\033[1;33m"
GREEN="\033[1;32m"
PURPLE="\033[1;35m"
WHITE="\033[1;37m"
BOLD=""
RESET="\033[m"

export MAGENTA
export ORANGE
export GREEN
export PURPLE
export WHITE
export BOLD
export RESET

if [ ! -f ~/code/dotfiles/.hostname ] && [ -f ~/code/dotfiles/.hostname.stub ]; then
    cp ~/code/dotfiles/.hostname.stub ~/code/dotfiles/.hostname
fi

# Prepend only what is missing, so nested shells do not stack up copies.
prepend_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

prepend_path "/opt/alt/alt-nodejs22/root/usr/bin"
prepend_path "$HOME/code/bin"
export PATH
unset -f prepend_path

source ~/code/dotfiles/.hostname
source ~/code/dotfiles/.aliases_git
source ~/code/dotfiles/.aliases_filesystem
source ~/code/dotfiles/.aliases_czu
source ~/code/dotfiles/.aliases_laravel

# Everything below is for interactive shells only. Bash also sources this file
# for non-interactive ssh commands (scp, rsync, git over ssh), and stray output
# on stdout breaks those protocols.
case $- in
    *i*) ;;
    *) return ;;
esac

if [ -z "${DOTFILES_HOSTNAME:-}" ]; then
    echo -e "${MAGENTA}Warning: DOTFILES_HOSTNAME is not set, edit ~/code/dotfiles/.hostname${RESET}"
    DOTFILES_HOSTNAME="unknown"
fi

function parse_git_dirty() {
    [[ $(git status 2> /dev/null | tail -n1) != *"working directory clean"* ]] && echo "*"
}

function parse_git_branch() {
    git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1$(parse_git_dirty)/"
}

export PS1="\[$ORANGE\][$DOTFILES_HOSTNAME] \[$WHITE\]in \[$GREEN\]\w\[$WHITE\]\$([[ -n \$(git branch 2> /dev/null) ]] && echo \" on \")\[$PURPLE\]\$(parse_git_branch)\[$WHITE\]\n\$ \[$RESET\]"

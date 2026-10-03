#!/usr/bin/env bash
iatest=$(expr index "$-" i)

if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

if [[ $iatest -gt 0 ]]; then bind "set bell-style visible"; fi

export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T"

export HISTCONTROL=erasedups:ignoredups:ignorespace

shopt -s checkwinsize

shopt -s histappend
PROMPT_COMMAND='history -a'

[[ $- == *i* ]] && stty -ixon

if [[ $iatest -gt 0 ]]; then bind "set completion-ignore-case on"; fi

if [[ $iatest -gt 0 ]]; then bind "set show-all-if-ambiguous On"; fi

export EDITOR=nvim
export VISUAL=nvim

export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'

if command -v rg &>/dev/null; then
    alias grep='rg'
else
    alias grep="/usr/bin/grep"
fi

export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias da='date "+%Y-%m-%d %A %T %Z"'

alias cp='cp -i'
alias mv='mv -i'
alias rm='trash -v'
alias mkdir='mkdir -p'
alias ps='ps auxf'
alias ping='ping -c 10'
alias less='less -R'
alias cls='clear'
alias vi='nvim'
alias svi='sudo vi'
alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"
alias o="xdg-open ."
alias cat='bat'

alias gaa='git add .'
alias gcm='git commit -m'
alias gpsh='git push'
alias gss='git status -s'
alias gs='echo ""; echo "*********************************************"; echo -e "   DO NOT FORGET TO PULL BEFORE COMMITTING"; echo "*********************************************"; echo ""; git status'

alias rmd='/bin/rm  --recursive --force --verbose '

alias la='ls -Alh'
alias ls='ls -aFh --color=always'
alias lx='ls -lXBh'
alias lk='ls -lSrh'
alias lc='ls -ltcrh'
alias lu='ls -lturh'
alias lr='ls -lRh'
alias lt='ls -ltrh'
alias lm='ls -alh |more'
alias lw='ls -xAh'
alias ll='ls -Fls'
alias labc='ls -lap'
alias lf="ls -l | egrep -v '^d'"
alias ldir="ls -l | egrep '^d'"
alias lla='ls -Al'
alias las='ls -A'
alias lls='ls -l'

alias h="history | grep "

alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

alias f="find . | grep "

alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"

alias checkcommand="type -t"

alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:$//g' | grep -v '[0-9]$' | xargs tail -f"

alias docker-clean=' \
  docker container prune -f ; \
  docker image prune -f ; \
  docker network prune -f ; \
  docker volume prune -f '

extract() {
    for archive in "$@"; do
        if [ -f "$archive" ]; then
            case $archive in
            *.tar.bz2) tar xvjf $archive ;;
            *.tar.gz) tar xvzf $archive ;;
            *.bz2) bunzip2 $archive ;;
            *.rar) rar x $archive ;;
            *.gz) gunzip $archive ;;
            *.tar) tar xvf $archive ;;
            *.tbz2) tar xvjf $archive ;;
            *.tgz) tar xvzf $archive ;;
            *.zip) unzip $archive ;;
            *.Z) uncompress $archive ;;
            *.7z) 7z x $archive ;;
            *) echo "don't know how to extract '$archive'..." ;;
            esac
        else
            echo "'$archive' is not a valid file!"
        fi
    done
}

ftext() {
    grep -iIHrn --color=always "$1" . | less -r
}

cpg() {
    if [ -d "$2" ]; then
        cp "$1" "$2" && { cd "$2" || return; }
    else
        cp "$1" "$2"
    fi
}

mvg() {
    if [ -d "$2" ]; then
        mv "$1" "$2" && { cd "$2" || return; }
    else
        mv "$1" "$2"
    fi
}

mkdirg() {
    mkdir -p "$1" || return
    cd "$1" || return
}

up() {
    # limit and i were not local, so both leaked into the interactive shell -
    # and a missing or non-numeric argument silently behaved like `up 1`
    # instead of saying anything.
    local limit="${1:-1}" d="" i

    if [[ ! $limit =~ ^[0-9]+$ ]] || ((limit < 1)); then
        echo "up: usage: up [number of directories]" >&2
        return 1
    fi

    for ((i = 1; i <= limit; i++)); do
        d="$d/.."
    done

    cd "${d#/}" || return
}

cd() {
    if [ -n "$1" ]; then
        builtin cd "$@" && ls
    else
        builtin cd ~ && ls
    fi
}

trim() {
    local var=$*
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# This file is a symlink that bash-setup.sh recreates from the repo. Installers
# such as nvm and bun append their activation lines to ~/.bashrc, and those
# appended lines are thrown away the moment the symlink is relinked - which is
# why tools "disappear" after running bash-setup.sh.
# Activating them here instead makes them survive. Put your own additions in
# ~/.bashrc.d/*.sh, which is sourced at the bottom and is never overwritten.

export PATH="$HOME/.local/bin:/var/lib/flatpak/exports/bin:$HOME/.local/share/flatpak/exports/bin:$PATH"

export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && . "$BUN_INSTALL/_bun"

# nvm - must be sourced, not just put on PATH: nvm is a shell function.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Point at the ssh-agent.service user unit, but only outside an SSH login:
# overwriting SSH_AUTH_SOCK on the remote end breaks agent forwarding.
# The -S test matters: if that unit was never enabled the socket does not
# exist, and exporting a path to nothing makes every ssh invocation complain
# about an unreachable agent instead of just falling back to the key file.
if [ -z "${SSH_CONNECTION:-}" ] &&
    [ -S "${XDG_RUNTIME_DIR:-/nonexistent}/ssh-agent.socket" ]; then
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
fi

if [[ $iatest -gt 0 ]] && command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
fi

if [ -d "$HOME/.bashrc.d" ]; then
    for _rc in "$HOME/.bashrc.d"/*.sh; do
        [ -r "$_rc" ] && . "$_rc"
    done
    unset _rc
fi

eval "$(starship init bash)"

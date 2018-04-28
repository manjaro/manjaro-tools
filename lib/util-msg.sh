#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

export LC_MESSAGES=C
export LANG=C

declare ALL_OFF='' BOLD='' BLUE='' GREEN='' RED='' YELLOW=''

if [[ -t 2 ]]; then
    # prefer terminal safe colored and bold text when tput is supported
    if tput setaf 0 &>/dev/null; then
        ALL_OFF="$(tput sgr0)"
        BOLD="$(tput bold)"
        RED="${BOLD}$(tput setaf 1)"
        GREEN="${BOLD}$(tput setaf 2)"
        YELLOW="${BOLD}$(tput setaf 3)"
        BLUE="${BOLD}$(tput setaf 4)"
    else
        ALL_OFF="\e[0m"
        BOLD="\e[1m"
        RED="${BOLD}\e[31m"
        GREEN="${BOLD}\e[32m"
        YELLOW="${BOLD}\e[33m"
        BLUE="${BOLD}\e[34m"
    fi
fi
readonly ALL_OFF BOLD BLUE GREEN RED YELLOW

plain() {
    local mesg=$1; shift
    printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
    local mesg=$1; shift
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
    local mesg=$1; shift
    printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

info() {
    local mesg=$1; shift
    printf "${YELLOW} -->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

warning() {
    local mesg=$1; shift
    printf "${YELLOW}==> WARNING:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
    local mesg=$1; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

stat_busy() {
    local mesg=$1; shift
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}...${ALL_OFF}" "$@" >&2
}

stat_done() {
    printf "${BOLD}done${ALL_OFF}\n" >&2
}

lock_close() {
	local fd=$1
	exec {fd}>&-
}

lock() {
    if ! [[ "/dev/fd/$1" -ef "$2" ]]; then
        mkdir -p -- "$(dirname -- "$2")"
        eval "exec $1>"'"$2"'
    fi
    if ! flock -n $1; then
        stat_busy "$3"
        flock $1
        stat_done
    fi
}

slock() {
    if ! [[ "/dev/fd/$1" -ef "$2" ]]; then
        mkdir -p -- "$(dirname -- "$2")"
        eval "exec $1>"'"$2"'
    fi
    if ! flock -sn $1; then
        stat_busy "$3"
        flock -s $1
        stat_done
    fi
}

cleanup() {
    exit ${1:-0}
}

abort() {
    error 'Aborting...'
    cleanup 255
}

die() {
    (( $# )) && error "$@"
    cleanup 255
}

import(){
    if [[ -r "$1" ]];then
        source "$1"
    else
        die 'Could not import %s' "$1"
    fi
}

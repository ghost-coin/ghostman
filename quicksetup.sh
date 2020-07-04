#!/usr/bin/env bash

# ghostman - main executable
# installs, updates, and manages ghost daemon

# Copyright (c) 2015-2017 moocowmoo
# Copyright (c) 2017 dasource

# check we're running bash 4 -------------------------------------------------
#set -x
sudo apt update
sudo apt-get install python git unzip pv jq dnsutils

if [ -z "$BASH_VERSION" ] || (( ${BASH_VERSION%%.*} < 4 )); then
    echo "ghostman requires bash version 4. please update. exiting." 1>&2
    exit 1
fi

# parse any command line switches --------------------------------------------

i=0
until [ "$((i=i+1))" -gt "$#" ]
do case "$1" in
    --help)    set -- "$@" "-h" ;;
    --quiet)   set -- "$@" "-q" ;;
    --version) set -- "$@" "-V" ;;
    *)         set -- "$@" "$1" ;;
esac; shift; done
OPTIND=1
while getopts "hqvV" o ; do # set $o to the next passed option
  case "$o" in
    q) QUIET=1 ;;
    V) VERSION=1 ;;
    h) HELP=1 ;;
    *) echo "Unknown option $o" 1>&2 ;;
  esac
done
shift $((OPTIND - 1))

# load common functions ------------------------------------------------------

GHOSTMAN_BIN=$(readlink -f "$0")
# shellcheck source=lib/functions.sh
source "lib/functions.sh"

# load language packs --------------------------------------------------------

declare -A messages

# set all default strings
source "lang/en_US.sh"

# override if configured
lang_type=${LANG%%\.*}
[[ -e lang/$lang_type.sh ]] && source "lang/$lang_type.sh"

# process switch overrides ---------------------------------------------------

# show version and exit if requested
[[ $VERSION || $1 == 'version' ]] && echo "$GHOSTMAN_VERSION" && exit 0

# show help and exit if requested or no command supplied - TODO make command specific
[[ $HELP || -z $1 ]] && usage && exit 0

# see if users are missing anything critical
_check_dependencies "$@"

UNATTENDED=1
install_ghostd
bash bin/ghostman.sh restart now
bash bin/ghostman.sh stakingnode init
bash bin/ghostman.sh stakingnode new



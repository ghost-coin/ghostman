#!/bin/bash

# ghostman - main executable
# installs, updates, and manages ghost daemon

# Copyright (c) 2015-2017 moocowmoo
# Copyright (c) 2017 dasource

# check we're running bash 4 -------------------------------------------------
#set -x

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
GHOSTMAN_GITDIR=$(readlink -f "${GHOSTMAN_BIN%%/bin/${GHOSTMAN_BIN##*/}}")
# shellcheck source=lib/functions.sh
source "$GHOSTMAN_GITDIR/lib/functions.sh"

# load language packs --------------------------------------------------------

declare -A messages

# set all default strings
source "$GHOSTMAN_GITDIR/lang/en_US.sh"

# override if configured
lang_type=${LANG%%\.*}
[[ -e $GHOSTMAN_GITDIR/lang/$lang_type.sh ]] && source "$GHOSTMAN_GITDIR/lang/$lang_type.sh"

# process switch overrides ---------------------------------------------------

# show version and exit if requested
[[ $VERSION || $1 == 'version' ]] && echo "$GHOSTMAN_VERSION" && exit 0

# show help and exit if requested or no command supplied - TODO make command specific
[[ $HELP || -z $1 ]] && usage && exit 0

# see if users are missing anything critical
_check_dependencies "$@"

# have command, will travel... -----------------------------------------------

echo -e "${C_CYAN}${messages["ghostman_version"]} $GHOSTMAN_VERSION$GHOSTMAN_CHECKOUT${C_NORM} - ${C_GREEN}$(date)${C_NORM}"

# do awesome stuff -----------------------------------------------------------
COMMAND=''
case "$1" in
        install)
            COMMAND=$1
            pending "${messages["gathering_info"]}"
            _check_ghostman_updates
            _get_versions
            ok " ${messages["done"]}"
            if [ -n "$2" ]; then
                APP=$2;
                if [ "$APP" == 'unattended' ]; then
                    UNATTENDED=1
                    install_ghostd
                else
                    echo "don't know how to install: $2"
                fi
            else
                install_ghostd
                show_message_configure
            fi
            quit
            ;;
        reinstall)
            COMMAND=$1
            pending "${messages["gathering_info"]}"
            _check_ghostman_updates
            _find_ghost_directory
            _get_versions
            _check_ghostd_state
            REINSTALL=1
            if [ -n "$2" ]; then
                if [ "$2" == '-prer' ]; then
                    PRER=1
                   _get_versions
                fi
            fi
            ok " ${messages["done"]}"
            update_ghostd
            ;;
        update)
            COMMAND=$1
            pending "${messages["gathering_info"]}"
            _check_ghostman_updates
            _find_ghost_directory
            _get_versions
            _check_ghostd_state
            ok " ${messages["done"]}"
            if [ -n "$2" ]; then
                if [ "$2" == '-y' ] || [ "$2" == '-Y' ]; then
                    UNATTENDED=1
                fi
                if [ "$2" == '-prer' ]; then
                    PRER=1
                   _get_versions
                fi
            fi
            update_ghostd
            ;;
        restart)
            COMMAND=$1
            _find_ghost_directory
            _check_ghostd_state
            case "$2" in
                now)
                    restart_ghostd
                    ;;
                *)
                    echo
                    pending "restart ghostd? "
                    confirm "[${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN" && \
                        restart_ghostd
                    ;;
            esac
            ;;
        status)
            COMMAND=$1
            pending "${messages["gathering_info"]}"
            _check_ghostman_updates
            _find_ghost_directory
            _get_versions
            _check_ghostd_state
            get_ghostd_status
            get_host_status
            ok " ${messages["done"]}"
            echo
            print_status
            quit 'Exiting.'
            ;;
        stakingnode)
            COMMAND=$1
            pending "${messages["gathering_info"]}"
            _check_ghostman_updates
            _find_ghost_directory
            _get_versions
            _check_ghostd_state
            ok " ${messages["done"]}"
            if [ -n "$2" ]; then
                APP=$2;
                if [ "$APP" == 'init' ]; then
                    stakingnode_walletinit
                elif [ "$APP" == 'new' ]; then
                    stakingnode_newpublickey
                elif [ "$APP" == 'info' ]; then
                    stakingnode_info
                elif [ "$APP" == 'stats' ]; then
                    stakingnode_stats
                elif [ "$APP" == 'rewardaddress' ]; then
                    stakingnode_rewardaddress
                elif [ "$APP" == 'smsgfeeratetarget' ]; then
                    stakingnode_smsgfeeratetarget
                else
                    echo "don't know how to stakingnode: $2"
                fi
            else
                stakingnode_info
            fi
            ;;
        proposal)
            COMMAND=$1
            pending "${messages["gathering_info"]}"
            _check_ghostman_updates
            _find_ghost_directory
            _get_versions
            _check_ghostd_state
            ok " ${messages["done"]}"
            if [ -n "$2" ]; then
                APP=$2;
                if [ "$APP" == 'list' ]; then
                    stakingnode_proposallist
                elif [ "$APP" == 'vote' ]; then
                    stakingnode_proposalvote
                elif [ "$APP" == 'tally' ]; then
                    stakingnode_proposaltally
                else
                    echo "don't know how to proposal: $2"
                fi
            else
                stakingnode_proposallist
            fi
            ;;
        firewall)
            COMMAND=$1
            pending "${messages["gathering_info"]}"
            ok " ${messages["done"]}"
            echo
            if [ -n "$2" ]; then
                APP=$2;
                if [ "$APP" == 'reset' ]; then
                    firewall_reset
                else
                    echo "don't know how to firewall: $2"
                fi
            else
                configure_firewall
        fi
            quit 'Exiting.'
            ;;
        getinfo)
            COMMAND=$1
            pending "${messages["gathering_info"]}"
            _check_ghostman_updates
            _find_ghost_directory
            _get_versions
            _check_ghostd_state
            ok " ${messages["done"]}"
            echo
            print_getinfo
            quit 'Exiting.'
            ;;
        *)
            usage
            ;;
esac

quit

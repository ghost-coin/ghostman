#!/bin/bash
# vim: set filetype=sh ts=4 sw=4 et

# functions.sh - common functions and variables

# Copyright (c) 2015-2017 moocowmoo
# Copyright (c) 2017 dasource

# variables are for putting things in ----------------------------------------

C_RED="\e[31m"
C_YELLOW="\e[33m"
C_GREEN="\e[32m"
C_PURPLE="\e[35m"
C_CYAN="\e[36m"
C_NORM="\e[0m"

GHOSTD_RUNNING=0
GHOSTD_RESPONDING=0
GHOSTMAN_VERSION=$(cat "$GHOSTMAN_GITDIR/VERSION")
DATA_DIR="$HOME/.ghost"
DOWNLOAD_PAGE="https://github.com/ghost-coin/ghost-intermediate/releases"
#GHOSTMAN_CHECKOUT=$(GIT_DIR=$GHOSTMAN_GITDIR/.git GIT_WORK_TREE=$GHOSTMAN_GITDIR git describe --dirty | sed -e "s/^.*-\([0-9]\+-g\)/\1/" )
#if [ "$GHOSTMAN_CHECKOUT" == "v"$GHOSTMAN_VERSION ]; then
#    GHOSTMAN_CHECKOUT=""
#else
#    GHOSTMAN_CHECKOUT=" ("$GHOSTMAN_CHECKOUT")"
#fi

curl_cmd="timeout 7 curl -4 -s -L -A ghostman/$GHOSTMAN_VERSION"
wget_cmd='wget -4 --no-check-certificate -q'


# (mostly) functioning functions -- lots of refactoring to do ----------------

pending(){ [[ $QUIET ]] || ( echo -en "$C_YELLOW$1$C_NORM" && tput el ); }

ok(){ [[ $QUIET ]] || echo -e "$C_GREEN$1$C_NORM" ; }

warn() { [[ $QUIET ]] || echo -e "$C_YELLOW$1$C_NORM" ; }
highlight() { [[ $QUIET ]] || echo -e "$C_PURPLE$1$C_NORM" ; }

err() { [[ $QUIET ]] || echo -e "$C_RED$1$C_NORM" ; }
die() { [[ $QUIET ]] || echo -e "$C_RED$1$C_NORM" ; exit 1 ; }

quit(){ [[ $QUIET ]] || echo -e "$C_GREEN${1:-${messages["exiting"]}}$C_NORM" ; echo ; exit 0 ; }

confirm() { read -r -p "$(echo -e "${1:-${messages["prompt_are_you_sure"]} [y/N]}")" ; [[ ${REPLY:0:1} = [Yy] ]]; }


up()     { echo -e "\e[${1:-1}A"; }
clear_n_lines(){ for n in $(seq "${1:-1}") ; do tput cuu 1; tput el; done ; }


usage(){
    cat<<EOF



    ${messages["usage"]}: ${0##*/} [command]

        ${messages["usage_title"]}

    ${messages["commands"]}

        install

            ${messages["usage_install_description"]}

        update

            ${messages["usage_update_description"]}

        selfupdate

            ${messages["usage_selfupdate_description"]}

        reinstall

            ${messages["usage_reinstall_description"]}

        restart [now]

            ${messages["usage_restart_description"]}
                banlist.dat
                peers.dat

            ${messages["usage_restart_description_now"]}

        stakingnode [init, new, info, stats, rewardaddress, smsgfeeratetarget]

            ${messages["usage_stakingnode_description"]}
            ${messages["usage_stakingnode_init_description"]}
            ${messages["usage_stakingnode_new_description"]}
            ${messages["usage_stakingnode_info_description"]}
            ${messages["usage_stakingnode_stats_description"]}
            ${messages["usage_stakingnode_rewardaddress_description"]}
            ${messages["usage_stakingnode_smsgfeeratetarget_description"]}

        status

            ${messages["usage_status_description"]}

        firewall [reset]

            ${messages["usage_firewall_description"]}
            ${messages["usage_firewall_reset"]}

        version

            ${messages["usage_version_description"]}

EOF
}

_check_dependencies() {

    INSTALL=install
    PYTHON=$( (type -P python 2>/dev/null) || (type -P python3 2>/dev/null))

    if [ -n "$PYTHON" ]; then
        DISTRO=$(/usr/bin/env "$PYTHON" -mplatform | sed -e 's/.*with-//g')
        if [[ $DISTRO == *"Ubuntu"* ]] || [[ $DISTRO == *"debian"* ]]; then
            PKG_MANAGER=apt-get
        elif [[ $DISTRO == *"centos"* ]]; then
            PKG_MANAGER=yum
        elif [[ $DISTRO == *"arch"* ]]; then
            PKG_MANAGER=pacman
        elif [[ $DISTRO == *"gentoo"* ]]; then
            PKG_MANAGER=emerge
            INSTALL=
        fi
    else
        echo -e "${C_RED}warning ${messages["no_python_fallback"]}$C_NORM"
        PKG_MANAGER=$( (type -P apt-get 2>/dev/null) \
                      || (type -P yum 2>/dev/null) \
                      || (type -P pacman 2>/dev/null) \
                      || (type -P emerge 2>/dev/null))
    fi

    if [[ $PKG_MANAGER == *"pacman" ]]; then
        INSTALL=-S
    elif [[ $PKG_MANAGER == *"emerge" ]]; then
        INSTALL=
    fi


    (type -P curl 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}curl "
    (type -P perl 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}perl "
    (type -P git  2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}git "
    (type -P jq   2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}jq "
    (type -P dig  2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}dnsutils "
    (type -P wget 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}wget "

    if [ "$1" == "install" ]; then
        # only require unzip for install
        (type -P unzip 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}unzip "
        (type -P pv   2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}pv "
    fi

    if [ "$1" == "firewall" ]; then
        # only require for firewall
        (type -P ufw  2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}ufw "
        FIREWALL_CLI="sudo ufw"
    fi

    # make sure we have the right netcat version (-4,-6 flags)
    if [ -n "$(type -P nc)" ]; then

        if ! (nc -z -4 8.8.8.8 53 2>&1) >/dev/null
        then
            MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}netcat6 "
        fi
    else
        MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}netcat "
    fi

    if [ -n "$MISSING_DEPENDENCIES" ]; then
        err "${messages["err_missing_dependency"]} $MISSING_DEPENDENCIES\n"
        if [ -z "$PKG_MANAGER" ]; then
            die "${messages["err_no_pkg_mgr"]}"
        fi
        # shellcheck disable=SC2086
        if ! sudo "$PKG_MANAGER" "$INSTALL" $MISSING_DEPENDENCIES; then
            die "${messages["err_no_pkg_mgr_install_failed"]}"
        fi
    fi
}

# attempt to locate ghost-cli executable.
# search current dir, ~/.ghost, `which ghost-cli` ($PATH), finally recursive
_find_ghost_directory() {

    INSTALL_DIR=''

    # ghost-cli in PATH

    if [ -n "$(type -P ghost-cli 2>/dev/null)" ] ; then
        INSTALL_DIR=$(readlink -f "$(type -P ghost-cli)")
        INSTALL_DIR=${INSTALL_DIR%%/ghost-cli*};

        #TODO prompt for single-user or multi-user install

        # if copied to /usr/*
        if [[ $INSTALL_DIR =~ \/usr.* ]]; then
            LINK_TO_SYSTEM_DIR=$INSTALL_DIR

            # if not run as root
            if [ $EUID -ne 0 ] ; then
                die "\n${messages["exec_found_in_system_dir"]} $INSTALL_DIR${messages["run_ghostman_as_root"]} ${messages["exiting"]}"
            fi
        fi

    # ghost-cli not in PATH

        # check current directory
    elif [ -e ./ghost-cli ] ; then
        INSTALL_DIR='.' ;

        # check ~/.ghost directory
    elif [ -e "$HOME/.ghost/ghost-cli" ] ; then
        INSTALL_DIR="$HOME/.ghost" ;

    elif [ -e "$HOME/ghostcore/ghost-cli" ] ; then
        INSTALL_DIR="$HOME/ghostcore" ;
    fi

    if [ -n "$INSTALL_DIR" ]; then
        INSTALL_DIR=$(readlink -f "$INSTALL_DIR") 2>/dev/null
        if [ ! -e "$INSTALL_DIR" ]; then
            echo -e "${C_RED}${messages["ghostcli_not_found_in_cwd"]}, ~/ghostcore, or \$PATH. -- ${messages["exiting"]}$C_NORM"
            exit 1
        fi
    else
        echo -e "${C_RED}${messages["ghostcli_not_found_in_cwd"]}, ~/ghostcore, or \$PATH. -- ${messages["exiting"]}$C_NORM"
        exit 1
    fi

    GHOST_CLI="$INSTALL_DIR/ghost-cli"

    # check INSTALL_DIR has ghostd and ghost-cli
    if [ ! -e "$INSTALL_DIR/ghostd" ]; then
        echo -e "${C_RED}${messages["ghostd_not_found"]} $INSTALL_DIR -- ${messages["exiting"]}$C_NORM"
        exit 1
    fi

    if [ ! -e "$GHOST_CLI" ]; then
        echo -e "${C_RED}${messages["ghostcli_not_found"]} $INSTALL_DIR -- ${messages["exiting"]}$C_NORM"
        exit 1
    fi

}


_check_ghostman_updates() {
    GITHUB_GHOSTMAN_VERSION=$( "$curl_cmd" -i https://raw.githubusercontent.com/ghost-coin/ghostman/master/VERSION 2>/dev/null | head -n 1 | cut -d$' ' -f2 )
    if [ "$GITHUB_GHOSTMAN_VERSION" == 200 ]; then # check to make sure github is returning the data
        GITHUB_GHOSTMAN_VERSION=$( $curl_cmd https://raw.githubusercontent.com/ghost-coin/ghostman/master/VERSION 2>/dev/null )
        if [ -n "$GITHUB_GHOSTMAN_VERSION" ] && [ "$GHOSTMAN_VERSION" != "$GITHUB_GHOSTMAN_VERSION" ]; then
            echo -e "\n"
            echo -e "${C_RED}${0##*/} ${messages["requires_updating"]} $C_GREEN$GITHUB_GHOSTMAN_VERSION$C_RED\n${messages["requires_sync"]}$C_NORM\n"

            die "${messages["exiting"]}"
        fi
    else
        GITHUB_GHOSTMAN_VERSION=$GHOSTMAN_VERSION # force to local version during github issues
    fi
}

_get_platform_info() {
    PLATFORM=$(uname -m)
    case "$PLATFORM" in
        i[3-6]86)
            BITS=32
            ARM=0
            ARCH='i686-pc-linux-gnu'
            QRCODE_ARCH='386'
            ;;
        x86_64)
            BITS=64
            ARM=0
            ARCH='x86_64-linux-gnu'
            QRCODE_ARCH='amd64'
            ;;
        armv7l)
            BITS=32
            ARM=1
            BIGARM=$(grep -Ec "(BCM2709|Freescale i\\.MX6)" /proc/cpuinfo)
            ARCH='arm-linux-gnueabihf'
            QRCODE_ARCH='arm'
            ;;
        aarch64)
            BITS=64
            ARM=1
            BIGARM=$(grep -Ec "(BCM2709|Freescale i\\.MX6)" /proc/cpuinfo)
            ARCH='aarch64-linux-gnu'
            QRCODE_ARCH='arm'
            ;;
        *)
            err "${messages["err_unknown_platform"]} $PLATFORM"
            err "${messages["err_ghostman_supports"]}"
            die "${messages["exiting"]}"
            ;;
    esac
}

_get_versions() {
    _get_platform_info

    if [ -z "$GHOST_CLI" ]; then GHOST_CLI='echo'; fi
    CURRENT_VERSION=$( $GHOST_CLI --version | grep -m1 Ghost | sed 's/\Ghost Core RPC client version v//g' | sed 's/\./\#/4' | sed 's/\#[^#]*$//' 2>/dev/null ) 2>/dev/null

    unset LATEST_VERSION
    LVCOUNTER=0
    RELEASES=$( $curl_cmd https://api.github.com/repos/ghost-coin/ghost-intermediate/releases )
    while [ -z "$LATEST_VERSION" ] && [ $LVCOUNTER -lt 5 ]; do
        RELEASE=$( echo "$RELEASES" | jq -r .[$LVCOUNTER] 2>/dev/null )
        PR=$( echo "$RELEASE" | jq .prerelease)
        if [ "$PR" == "false" ] || [ "$PRER" == 1 ]; then
            LATEST_VERSION=$( echo "$RELEASE" | jq -r .tag_name | sed 's/v//g')
        else
            (( LVCOUNTER=LVCOUNTER+1 ))
        fi
    done

    if [ -z "$LATEST_VERSION" ] && [ "$COMMAND" == "install" ]; then
        die "\n${messages["err_could_not_get_version"]} $DOWNLOAD_PAGE -- ${messages["exiting"]}"
    fi

    DOWNLOAD_URL="https://github.com/ghost-coin/ghost-intermediate/releases/download/v${LATEST_VERSION}/ghost-${LATEST_VERSION}-${ARCH}.tgz"
    DOWNLOAD_FILE="ghost-${LATEST_VERSION}-${ARCH}.tgz"

}

_check_ghostd_state() {
    _get_ghostd_proc_status
    GHOSTD_RUNNING=0
    GHOSTD_RESPONDING=0
    if [ "$GHOSTD_HASPID" -gt 0 ] && [ "$GHOSTD_PID" -gt 0 ]; then
        GHOSTD_RUNNING=1
    fi
    if [ "$( $GHOST_CLI help 2>/dev/null | wc -l )" -gt 0 ]; then
        GHOSTD_RESPONDING=1
        GHOSTD_FIRSTWALLET=$( ls -1 $DATA_DIR/wallets | grep -v \.dat | grep -v \.log | head -n 1 )
        GHOSTD_WALLETSTATUS=$( "$GHOST_CLI" -rpcwallet=$GHOSTD_FIRSTWALLET getwalletinfo )
        GHOSTD_WALLET=$( echo $GHOSTD_WALLETSTATUS | jq -r .hdmasterkeyid )
        if [ "$GHOSTD_WALLET"  == "null" ]; then
            GHOSTD_WALLET=$( "$GHOST_CLI" -rpcwallet=$GHOSTD_FIRSTWALLET getwalletinfo | jq -r .hdseedid )
        fi
        GHOSTD_TBALANCE=$( "$GHOST_CLI" -rpcwallet=$GHOSTD_FIRSTWALLET getwalletinfo | jq -r .total_balance )
    fi
}

restart_ghostd(){

    if [ "$GHOSTD_RUNNING" == 1 ]; then
        pending " --> ${messages["stopping"]} ghostd. ${messages["please_wait"]}"
        $GHOST_CLI stop > /dev/null 2>&1
        sleep 15
        killall -9 ghostd ghost-shutoff 2>/dev/null
        ok "${messages["done"]}"
        GHOSTD_RUNNING=0
    fi

    pending " --> ${messages["deleting_cache_files"]} $DATA_DIR/ "

    cd "$INSTALL_DIR" || exit

    #rm -rf \
    #    "$DATA_DIR"/banlist.dat \
    #    "$DATA_DIR"/peers.dat
    ok "${messages["done"]}"

    pending " --> ${messages["starting_ghostd"]}"
    "$INSTALL_DIR/ghostd" -daemon > /dev/null 2>&1
    GHOSTD_RUNNING=1
    GHOSTD_RESPONDING=0
    ok "${messages["done"]}"

    pending " --> ${messages["waiting_for_ghostd_to_respond"]}"
    echo -en "${C_YELLOW}"
    while [ $GHOSTD_RUNNING == 1 ] && [ $GHOSTD_RESPONDING == 0 ]; do
        echo -n "."
        _check_ghostd_state
        sleep 5
    done
    if [ $GHOSTD_RUNNING == 0 ]; then
        die "\n - ghostd unexpectedly quit. ${messages["exiting"]}"
    fi
    ok "${messages["done"]}"
    pending " --> ghost-cli getinfo"
    echo
    $GHOST_CLI -getinfo
    echo

}

install_ghostd(){

    INSTALL_DIR=$HOME/ghostcore
    GHOST_CLI="$INSTALL_DIR/ghost-cli"

    if [ -e "$INSTALL_DIR" ] ; then
        die "\n - ${messages["preexisting_dir"]} $INSTALL_DIR ${messages["found"]} ${messages["run_reinstall"]} ${messages["exiting"]}"
    fi

    if [ -z "$UNATTENDED" ] ; then
        if [ "$USER" != "ghost" ]; then
            echo
            warn "We strongly advise you run this installer under user \"ghost\" with sudo access. Are you sure you wish to continue as $USER?"
            if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
                echo -e "${C_RED}${messages["exiting"]}$C_NORM"
                echo ""
                exit 0
            fi
        fi
        pending "${messages["download"]} $DOWNLOAD_URL\n${messages["and_install_to"]} $INSTALL_DIR?"
    else
        echo -e "$C_GREEN*** UNATTENDED MODE ***$C_NORM"
    fi

    if [ -z "$UNATTENDED" ] ; then
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi
    fi

    get_public_ips
    echo ""

    # prep it ----------------------------------------------------------------

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"

    if [ ! -e "$DATA_DIR/ghost.conf" ] ; then
        pending " --> ${messages["creating"]} $DATA_DIR/ghost.conf... "

        while read -r; do
            eval echo "$REPLY"
        done < "$GHOSTMAN_GITDIR/ghost.conf.template" > "$DATA_DIR/ghost.conf"
        ok "${messages["done"]}"
    fi

    # push it ----------------------------------------------------------------

    cd "$INSTALL_DIR" || exit

    # pull it ----------------------------------------------------------------

    pending " --> ${messages["downloading"]} ${DOWNLOAD_URL}... "
    tput sc
    echo -e "$C_CYAN"
    $wget_cmd -O - "$DOWNLOAD_URL" | pv -trep -s27M -w80 -N wallet > "$DOWNLOAD_FILE"
    $wget_cmd -O - "https://raw.githubusercontent.com/ghost-coin/gitian.sigs/master/${LATEST_VERSION}-linux/akshaynexus/ghost-linux-${LATEST_VERSION}-build.assert" | pv -trep -w80 -N checksums > "${DOWNLOAD_FILE}.DIGESTS.txt"
    echo -ne "$C_NORM"
    clear_n_lines 2
    tput rc
    clear_n_lines 3
    if [ ! -e "$DOWNLOAD_FILE" ] ; then
        echo -e "${C_RED}error ${messages["downloading"]} file"
        echo -e "tried to get $DOWNLOAD_URL$C_NORM"
        exit 1
    else
        ok "${messages["done"]}"
    fi

    # produce it -------------------------------------------------------------

    pending " --> ${messages["unpacking"]} ${DOWNLOAD_FILE}... " && \
    tar zxf "$DOWNLOAD_FILE" && \
    ok "${messages["done"]}"

    # pummel it --------------------------------------------------------------

    if [ $GHOSTD_RUNNING == 1 ]; then
        pending " --> ${messages["stopping"]} ghostd. ${messages["please_wait"]}"
        $GHOST_CLI stop >/dev/null 2>&1
        sleep 15
        killall -9 ghostd ghost-shutoff >/dev/null 2>&1
        ok "${messages["done"]}"
    fi

    # place it ---------------------------------------------------------------

    mv "ghost-$LATEST_VERSION/bin/ghostd" "ghostd-$LATEST_VERSION"
    mv "ghost-$LATEST_VERSION/bin/ghost-cli" "ghost-cli-$LATEST_VERSION"
    mv "ghost-$LATEST_VERSION/bin/ghost-wallet" "ghost-wallet-$LATEST_VERSION"
    if [ $ARM != 1 ];then
        mv "ghost-$LATEST_VERSION/bin/ghost-qt" "ghost-qt-$LATEST_VERSION"
    fi
    ln -s "ghostd-$LATEST_VERSION" ghostd
    ln -s "ghost-cli-$LATEST_VERSION" ghost-cli
    ln -s "ghost-wallet-$LATEST_VERSION" ghost-wallet
    if [ $ARM != 1 ];then
        ln -s "ghost-qt-$LATEST_VERSION" ghost-qt
    fi

    # permission it ----------------------------------------------------------

    if [ -n "$SUDO_USER" ]; then
        chown -h "$USER":"$USER" {"$DOWNLOAD_FILE","${DOWNLOAD_FILE}.DIGESTS.txt",ghost-cli,ghostd,ghost-qt,ghost-wallet,ghost*"$LATEST_VERSION"}
    fi

    # purge it ---------------------------------------------------------------

    rm -rf "ghost-$LATEST_VERSION"

    # path it ----------------------------------------------------------------

    pending " --> adding $INSTALL_DIR PATH to ~/.bash_aliases ... "
    if [ ! -f ~/.bash_aliases ]; then touch ~/.bash_aliases ; fi
    sed -i.bak -e '/ghostman_env/d' ~/.bash_aliases
    echo "export PATH=$INSTALL_DIR:\$PATH; # ghostman_env" >> ~/.bash_aliases
    ok "${messages["done"]}"

    # autoboot it ------------------------------------------------------------

    INIT=$(ps --no-headers -o comm 1)
    if [ "$INIT" == "systemd" ] && [ "$USER" == "ghost" ] && [ -n "$SUDO_USER" ]; then
        pending " --> detecting $INIT for auto boot ($USER) ... "
        ok "${messages["done"]}"
        DOWNLOAD_SERVICE="https://raw.githubusercontent.com/ghost-coin/ghost-intermediate/master/contrib/init/ghostd.service"
        pending " --> [systemd] ${messages["downloading"]} ${DOWNLOAD_SERVICE}... "
        $wget_cmd -O - $DOWNLOAD_SERVICE | pv -trep -w80 -N service > ghostd.service
        if [ ! -e ghostd.service ] ; then
           echo -e "${C_RED}error ${messages["downloading"]} file"
           echo -e "tried to get ghostd.service$C_NORM"
        else
           ok "${messages["done"]}"
        pending " --> [systemd] installing service ... "
        if sudo cp -rf ghostd.service /etc/systemd/system/; then
            ok "${messages["done"]}"
        fi
           pending " --> [systemd] reloading systemd service ... "
        if sudo systemctl daemon-reload; then
            ok "${messages["done"]}"
        fi
           pending " --> [systemd] enable ghostd system startup ... "
        if sudo systemctl enable ghostd; then
               ok "${messages["done"]}"
           fi
        fi
    fi

    # sniff it ---------------------------------------------------------------
    install_ghost_runonce

    # poll it ----------------------------------------------------------------

    _get_versions

    # pass or punt -----------------------------------------------------------

    if [ "$LATEST_VERSION" == "$CURRENT_VERSION" ]; then
        echo -e ""
        echo -e "${C_GREEN}Ghost ${LATEST_VERSION} ${messages["successfully_installed"]}$C_NORM"

        echo -e ""
        echo -e "${C_GREEN}${messages["installed_in"]} ${INSTALL_DIR}$C_NORM"
        echo -e ""
        ls -l --color {"$DOWNLOAD_FILE","${DOWNLOAD_FILE}.DIGESTS.txt",ghost-cli,ghostd,ghost-qt,ghost-wallet,ghost*"$LATEST_VERSION"}
        echo -e ""

        if [ -n "$SUDO_USER" ]; then
            echo -e "${C_GREEN}Symlinked to: ${LINK_TO_SYSTEM_DIR}$C_NORM"
            echo -e ""
            ls -l --color "$LINK_TO_SYSTEM_DIR"/{ghostd,ghost-cli,ghost-wallet}
            echo -e ""
        fi

    else
        echo -e "${C_RED}${messages["ghost_version"]} $CURRENT_VERSION ${messages["is_not_uptodate"]} ($LATEST_VERSION) ${messages["exiting"]}$C_NORM"
        exit 1
    fi
}

install_ghost_runonce() {
    INSTALL_DIR=$HOME/ghostcore
    GHOST_WALLET="$INSTALL_DIR/ghost-wallet"
    $GHOST_WALLET -wallet="" create
}

update_ghostd(){

    if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ] || [ -n "$REINSTALL" ] ; then

        if [ -n "$REINSTALL" ];then
            echo -e ""
            echo -e "$C_GREEN*** ${messages["ghost_version"]} $CURRENT_VERSION is up-to-date. ***$C_NORM"
            echo -e "${messages["latest_version"]} $C_GREEN$LATEST_VERSION$C_NORM"
            echo -e ""
            echo -en

            pending "${messages["reinstall_to"]} $INSTALL_DIR$C_NORM?"
        else
            echo -e ""
            echo -e "$C_RED*** ${messages["newer_ghost_available"]} ***$C_NORM"
            echo -e ""
            echo -e "${messages["currnt_version"]} $C_RED$CURRENT_VERSION$C_NORM"
            echo -e "${messages["latest_version"]} $C_GREEN$LATEST_VERSION$C_NORM"
            echo -e ""
            if [ -z "$UNATTENDED" ] ; then
                pending "${messages["download"]} $DOWNLOAD_URL\n${messages["and_install_to"]} $INSTALL_DIR?"
            else
                echo -e "$C_GREEN*** UNATTENDED MODE ***$C_NORM"
            fi
        fi


        if [ -z "$UNATTENDED" ] ; then
            if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
                echo -e "${C_RED}${messages["exiting"]}$C_NORM"
                echo ""
                exit 0
            fi
        fi

        # push it ----------------------------------------------------------------

        cd "$INSTALL_DIR" || exit

        # pull it ----------------------------------------------------------------

        pending " --> ${messages["downloading"]} ${DOWNLOAD_URL}... "
        tput sc
        echo -e "$C_CYAN"
        $wget_cmd -O - "$DOWNLOAD_URL" | pv -trep -s27M -w80 -N wallet > "$DOWNLOAD_FILE"
        $wget_cmd -O - "https://raw.githubusercontent.com/ghost-coin/gitian.sigs/master/$LATEST_VERSION.0-linux/akshaynexus/ghost-linux-$LATEST_VERSION-build.assert" | pv -trep -w80 -N checksums > "${DOWNLOAD_FILE}.DIGESTS.txt"
        echo -ne "$C_NORM"
        clear_n_lines 2
        tput rc
        clear_n_lines 3
        if [ ! -e "$DOWNLOAD_FILE" ] ; then
            echo -e "${C_RED}error ${messages["downloading"]} file"
            echo -e "tried to get $DOWNLOAD_URL$C_NORM"
            exit 1
        else
            ok "${messages["done"]}"
        fi

        # produce it -------------------------------------------------------------

        pending " --> ${messages["unpacking"]} ${DOWNLOAD_FILE}... " && \
        tar zxf "$DOWNLOAD_FILE" && \
        ok "${messages["done"]}"

        # pummel it --------------------------------------------------------------

        if [ $GHOSTD_RUNNING == 1 ]; then
            pending " --> ${messages["stopping"]} ghostd. ${messages["please_wait"]}"
            $GHOST_CLI stop >/dev/null 2>&1
            sleep 15
            killall -9 ghostd ghost-shutoff >/dev/null 2>&1
            ok "${messages["done"]}"
        fi

        # prune it ---------------------------------------------------------------

        pending " --> ${messages["removing_old_version"]}"
        rm -rf \
            ghostd \
            "ghostd-$CURRENT_VERSION" \
            ghost-qt \
            "ghost-qt-$CURRENT_VERSION" \
            ghost-cli \
            "ghost-cli-$CURRENT_VERSION" \
            ghost-wallet \
            "ghost-wallet-$CURRENT_VERSION"
        #rm -rf \
        #    "$DATA_DIR"/banlist.dat \
        #    "$DATA_DIR"/peers.dat
        ok "${messages["done"]}"

        # place it ---------------------------------------------------------------

        mv "ghost-$LATEST_VERSION/bin/ghostd" "ghostd-$LATEST_VERSION"
        mv "ghost-$LATEST_VERSION/bin/ghost-cli" "ghost-cli-$LATEST_VERSION"
        mv "ghost-$LATEST_VERSION/bin/ghost-wallet" "ghost-wallet-$LATEST_VERSION"
        if [ $ARM != 1 ];then
            mv "ghost-$LATEST_VERSION/bin/ghost-qt" "ghost-qt-$LATEST_VERSION"
        fi
        ln -s "ghostd-$LATEST_VERSION" ghostd
        ln -s "ghost-cli-$LATEST_VERSION" ghost-cli
        ln -s "ghost-wallet-$LATEST_VERSION" ghost-wallet
        if [ $ARM != 1 ];then
            ln -s "ghost-qt-$LATEST_VERSION" ghost-qt
        fi

        # permission it ----------------------------------------------------------

        if [ -n "$SUDO_USER" ]; then
            chown -h "$USER":"$USER" {"$DOWNLOAD_FILE","${DOWNLOAD_FILE}.DIGESTS.txt",ghost-cli,ghostd,ghost-qt,ghost-wallet,ghost*"$LATEST_VERSION"}
        fi

        # purge it ---------------------------------------------------------------

        rm -rf "ghost-${LATEST_VERSION}"

        # punch it ---------------------------------------------------------------

        pending " --> ${messages["launching"]} ghostd... "
        "$INSTALL_DIR/ghostd" -daemon > /dev/null 2>&1
        ok "${messages["done"]}"

        # probe it ---------------------------------------------------------------

        pending " --> ${messages["waiting_for_ghostd_to_respond"]}"
        echo -en "${C_YELLOW}"
        GHOSTD_RUNNING=1
        while [ $GHOSTD_RUNNING == 1 ] && [ $GHOSTD_RESPONDING == 0 ]; do
            echo -n "."
            _check_ghostd_state
            sleep 5
        done
        if [ $GHOSTD_RUNNING == 0 ]; then
            die "\n - ghostd unexpectedly quit. ${messages["exiting"]}"
        fi
        ok "${messages["done"]}"

        # poll it ----------------------------------------------------------------

        _get_versions

        # pass or punt -----------------------------------------------------------

        if [ "$LATEST_VERSION" == "$CURRENT_VERSION" ]; then
            echo -e ""
            echo -e "${C_GREEN}${messages["successfully_upgraded"]} ${LATEST_VERSION}$C_NORM"

            echo -e ""
            echo -e "${C_GREEN}${messages["installed_in"]} ${INSTALL_DIR}$C_NORM"
            echo -e ""
            ls -l --color {"$DOWNLOAD_FILE","${DOWNLOAD_FILE}.DIGESTS.txt",ghost-cli,ghostd,ghost-qt,ghost*"$LATEST_VERSION"}
            echo -e ""

            quit ""
        else
            echo -e "${C_RED}${messages["ghost_version"]} $CURRENT_VERSION ${messages["is_not_uptodate"]} ($LATEST_VERSION) ${messages["exiting"]}$C_NORM"
        fi
    else
        echo -e ""
        echo -e "${C_GREEN}${messages["ghost_version"]} $CURRENT_VERSION ${messages["is_uptodate"]} ($LATEST_VERSION) ${messages["exiting"]}$C_NORM"
    fi
    exit 0
}

stakingnode_walletinit(){

    echo "$GHOSTD_WALLET"
    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            die "\n - wallet already exists - 'ghostman stakingnode' to view list of current staking node public keys or 'ghostman stakingnode new' to create a new staking node public key. ${messages["exiting"]}"
        else
            ok "${messages["done"]}"
        fi

        echo
        pending " --> ${messages["stakingnode_init_walletgenerate"]}"
        MNEMONIC=$( $GHOST_CLI mnemonic new | grep mnemonic | cut -f2 -d":" | sed 's/\ "//g' | sed 's/\",//g' )
        MNEMONIC_COUNT=$(echo "$MNEMONIC" | wc -w)
        if [ "$MNEMONIC_COUNT" == 24 ]; then
            highlight "$MNEMONIC"
        else
            exit 1
        fi

        echo
        warn "Have you written down your recovery phrase?"
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi

        pending " --> ${messages["stakingnode_init_walletcreate"]}"
        if $GHOST_CLI extkeyimportmaster "$MNEMONIC" >/dev/null 2>&1; then
            ok "${messages["done"]}"
        else
            die "\n - failed to create new wallet ${messages["exiting"]}"
        fi
    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi

    echo
    echo -e "    ${C_YELLOW}ghostman stakingnode info$C_NORM"
    echo

}

stakingnode_newpublickey(){

    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            ok "${messages["done"]}"
        else
            die "\n - no wallet exists, please type 'ghostman stakingnode init' ${messages["exiting"]}"
        fi
        if [ "$GHOSTD_TBALANCE" -gt 0 ]; then
            die "\n - WOAH holdup! you cannot setup coldstaking on a hotstaking wallet! ${messages["exiting"]}"
        fi

        echo

        pending "Create new staking node public key?"
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi

        pending "Label for new key : "
        read -r pubkeylabel

        echo
        pending " --> ${messages["stakingnode_new_publickey"]}"
        if $GHOST_CLI getnewextaddress "stakingnode_$pubkeylabel"; then
            ok ""
        else
            die "\n - error creating new staking node public key! ' ${messages["exiting"]}"
        fi
    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi


}

stakingnode_rewardaddress(){

    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            ok "${messages["done"]}"
        else
            die "\n - no wallet exists, please type 'ghostman stakingnode init' ${messages["exiting"]}"
        fi
        if [ "$GHOSTD_TBALANCE" -gt 0 ]; then
            die "\n -  WOAH holdup! you cannot setup coldstaking on a hotstaking wallet! ${messages["exiting"]}"
        fi
        echo

        pending " --> ${messages["stakingnode_reward_check"]}"
        STAKE_OPTS=$($GHOST_CLI walletsettings stakingoptions | jq .stakingoptions)
        if [ "$STAKE_OPTS" == "\"default\"" ]; then
            STAKE_OPTS="{}"
        fi
        REWARD_ADDRESS=$(echo "$STAKE_OPTS" | jq -r .rewardaddress)
        if [ -n "$REWARD_ADDRESS" ] && [ "$REWARD_ADDRESS" != "null" ] ; then
            REWARD_ADDRESS_DATE=$(echo "$STAKE_OPTS" | jq -r .time)
            REWARD_ADDRESS_DATEFORMATTED=$(stamp2date "$REWARD_ADDRESS_DATE")
            ok "${messages["done"]}"
            pending " --> ${messages["stakingnode_reward_found"]}"
            highlight "$REWARD_ADDRESS (Set on $REWARD_ADDRESS_DATEFORMATTED)"
        else
            ok "${messages["done"]}"
            pending " --> ${messages["stakingnode_reward_found"]}"
            highlight "default mode"
            echo -e "** Your wallet is configured in default mode - it will send the staking rewards back to the staking address."
        fi

        echo
        pending "Configure a new reward address?"
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi

        pending "Ghost Address to send all rewards to : "
        read -r rewardAddress

        echo
        pending " --> ${messages["stakingnode_reward_address"]}"

        STAKE_OPTS=$(echo "$STAKE_OPTS" | jq 'del(.time)')
        if [ -z "$rewardAddress" ]
        then
            STAKE_OPTS=$(echo "$STAKE_OPTS" | jq 'del(.rewardaddress)')
        else
            STAKE_OPTS=$(echo "$STAKE_OPTS" | jq ".rewardaddress = \"${rewardAddress}\"")
        fi

        echo
        if "$GHOST_CLI" walletsettings stakingoptions "$STAKE_OPTS"; then
            ok ""
        else
            die "\n - error setting the reward address! ' ${messages["exiting"]}"
        fi
    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi


}

stakingnode_smsgfeeratetarget(){

    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            ok "${messages["done"]}"
        else
            die "\n - no wallet exists, please type 'ghostman stakingnode init' ${messages["exiting"]}"
        fi
        if [ "$GHOSTD_TBALANCE" -gt 0 ]; then
            die "\n -  WOAH holdup! you cannot setup coldstaking on a hotstaking wallet! ${messages["exiting"]}"
        fi
        echo

        pending " --> ${messages["stakingnode_smsgfeerate_check"]}"
        STAKE_OPTS=$($GHOST_CLI walletsettings stakingoptions | jq .stakingoptions)
        if [ "$STAKE_OPTS" == "\"default\"" ]; then
            STAKE_OPTS="{}"
        fi
        SMSG_FEE_RATE_TARGET=$(echo "$STAKE_OPTS" | jq -r .smsgfeeratetarget)
        if [ -n "$SMSG_FEE_RATE_TARGET" ] && [ "$SMSG_FEE_RATE_TARGET" != "null" ] ; then
            SMSG_FEE_RATE_TARGET_DATE=$(echo "$STAKE_OPTS" | jq -r .time)
            SMSG_FEE_RATE_TARGET_DATEFORMATTED=$(stamp2date "$SMSG_FEE_RATE_TARGET_DATE")
            ok "${messages["done"]}"
            pending " --> ${messages["stakingnode_smsgfeerate_found"]}"
            highlight "$SMSG_FEE_RATE_TARGET (Set on $SMSG_FEE_RATE_TARGET_DATEFORMATTED)"
        else
            ok "${messages["done"]}"
            pending " --> ${messages["stakingnode_smsgfeerate_found"]}"
            highlight "default mode"
            echo -e "** Your wallet is configured in default mode - it will not attempt to adjust the smsg fee rate."
        fi

        echo
        pending "Configure a new smsg fee rate target?"
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi

        echo ""
        pending "** ghostman recommends a smsg fee rate of : "
        highlight "0.00020000"
        echo ""
        pending "Amount to adjust the smsg fee rate towards : "
        read -r feeRateTarget

        echo
        pending " --> ${messages["stakingnode_smsgfeerate_address"]}"

        STAKE_OPTS=$(echo "$STAKE_OPTS" | jq 'del(.time)')
        if [ -z "$feeRateTarget" ]
        then
            STAKE_OPTS=$(echo "$STAKE_OPTS" | jq 'del(.smsgfeeratetarget)')
        else
            STAKE_OPTS=$(echo "$STAKE_OPTS" | jq ".smsgfeeratetarget = \"${feeRateTarget}\"")
        fi

        echo
        if "$GHOST_CLI" walletsettings stakingoptions "$STAKE_OPTS"; then
            ok ""
        else
            die "\n - error setting the smsg fee rate target! ' ${messages["exiting"]}"
        fi
    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi


}

stakingnode_info(){
    _check_qrcode

    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            ok "${messages["done"]}"
        else
            die "\n - no wallet exists, please type 'ghostman stakingnode init' ${messages["exiting"]}"
        fi

        ACCOUNTID=$( $GHOST_CLI extkey account | grep "\"id"\" | cut -f2 -d":" | sed 's/\ "//g' | sed 's/\",//g' )

        echo
        FOUNDSTAKINGNODEKEY=0
        for ID in $ACCOUNTID;
        do
            IDINFO=$($GHOST_CLI extkey key "$ID" true 2>&-)
            IDINFO_LABEL=$( echo "$IDINFO" | jq -r .label)
            if echo "$IDINFO_LABEL" | grep -q "stakingnode"; then
                IDINFO_PUBKEY=$( echo "$IDINFO" | jq -r .epkey)
                pending " --> Staking Node Label : "
                ok "$IDINFO_LABEL"
                pending " --> Staking Node Public Key : "
                ok "$IDINFO_PUBKEY"
                if [ -e "$INSTALL_DIR/qrcode" ] ; then
                    "$INSTALL_DIR/qrcode" "$IDINFO_PUBKEY"
                fi
                echo
                FOUNDSTAKINGNODEKEY=1
            fi
        done

        if [ $FOUNDSTAKINGNODEKEY == 0 ] || [ -z $FOUNDSTAKINGNODEKEY ]; then
            die " - no staking node public keys found, please type 'ghostman stakingnode new' to create one. ${messages["exiting"]}"
        fi
    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi

}

_check_qrcode() {
    if [ ! -e "$INSTALL_DIR/qrcode" ] ; then
        QRCODE_DOWNLOAD_URL="https://github.com/spazzymoto/qrcode/releases/download/v1.0.0/qrcode_linux_$QRCODE_ARCH"
        pending " --> ${messages["downloading"]} ${QRCODE_DOWNLOAD_URL}... "
        tput sc
        echo -e "$C_CYAN"
        $wget_cmd -O - $QRCODE_DOWNLOAD_URL | pv -trep -s27M -w80 -N qrcode > "$INSTALL_DIR/qrcode"
        echo -ne "$C_NORM"
        clear_n_lines 2
        tput rc
        clear_n_lines 3
        if [ ! -e "$INSTALL_DIR/qrcode" ] ; then
            echo -e "${C_RED}error ${messages["downloading"]} file"
            echo -e "tried to get $QRCODE_DOWNLOAD_URL$C_NORM"
            exit 1
        else
            chmod +x "$INSTALL_DIR/qrcode"
            ok "${messages["done"]}"
        fi
    fi
}

stakingnode_stats(){

    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            ok "${messages["done"]}"
        else
            die "\n - no wallet exists, please type 'ghostman stakingnode init' ${messages["exiting"]}"
        fi
        if [ ! "$LATEST_VERSION" == "$CURRENT_VERSION" ]; then
            die "\n - please upgrade to the latest version! ${messages["exiting"]}"
        fi

        DAY=$(date -u +%d)
        MONTH=$(date -u +%m)
        YEAR=$(date -u +%Y)

        COUNTER=1

        pending " --> ${messages["stakingnode_stats_daily"]}"
        ok "${messages["done"]}"
        echo
        printf '%-4s %-15s %-30s %-12s\n' \
        "${messages["stakingnode_stats_indent"]}" "DAY" "# STAKES" "TOTAL STAKED"

        until [ $COUNTER -gt "$DAY" ]; do
            NUMBER_OF_STAKES=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$MONTH-$COUNTER\", \"to\":\"$YEAR-$MONTH-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.records)
            STAKE_AMOUNT=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$MONTH-$COUNTER\", \"to\":\"$YEAR-$MONTH-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.total_reward)

            printf '%-4s %-15s %-30s %-12s\n' \
            "${messages["stakingnode_stats_indent"]}" "$COUNTER" "$NUMBER_OF_STAKES" "$STAKE_AMOUNT"
            COUNTER=$((COUNTER+1))
        done

        echo
        pending " --> ${messages["stakingnode_stats_monthly"]}"
        ok "${messages["done"]}"
        echo
        printf '%-4s %-15s %-30s %-12s\n' \
        "${messages["stakingnode_stats_indent"]}" "MONTH" "# STAKES" "TOTAL STAKED"

        COUNTER=12
        until [ $COUNTER == 0 ]; do
            NUMBER_OF_STAKES=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$COUNTER\", \"to\":\"$YEAR-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.records)
            STAKE_AMOUNT=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$COUNTER\", \"to\":\"$YEAR-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.total_reward)
            if [[ $NUMBER_OF_STAKES != 0 ]] && [[ $STAKE_AMOUNT != 0 ]]; then
                printf '%-4s %-15s %-30s %-12s\n' \
                "${messages["stakingnode_stats_indent"]}" "$COUNTER ($YEAR)" "$NUMBER_OF_STAKES" "$STAKE_AMOUNT"
            fi
            COUNTER=$((COUNTER-1))
        done

        echo
        COUNTER=12
        YEAR=2019
        until [ $COUNTER == 0 ]; do
            NUMBER_OF_STAKES=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$COUNTER\", \"to\":\"$YEAR-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.records)
            STAKE_AMOUNT=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$COUNTER\", \"to\":\"$YEAR-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.total_reward)
            if [[ $NUMBER_OF_STAKES != 0 ]] && [[ $STAKE_AMOUNT != 0 ]]; then
                printf '%-4s %-15s %-30s %-12s\n' \
                "${messages["stakingnode_stats_indent"]}" "$COUNTER ($YEAR)" "$NUMBER_OF_STAKES" "$STAKE_AMOUNT"
            fi
            COUNTER=$((COUNTER-1))
        done

        echo
        COUNTER=12
        YEAR=2018
        until [ $COUNTER == 0 ]; do
            NUMBER_OF_STAKES=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$COUNTER\", \"to\":\"$YEAR-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.records)
            STAKE_AMOUNT=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$COUNTER\", \"to\":\"$YEAR-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.total_reward)
            if [[ $NUMBER_OF_STAKES != 0 ]] && [[ $STAKE_AMOUNT != 0 ]]; then
                printf '%-4s %-15s %-30s %-12s\n' \
                "${messages["stakingnode_stats_indent"]}" "$COUNTER ($YEAR)" "$NUMBER_OF_STAKES" "$STAKE_AMOUNT"
            fi
            COUNTER=$((COUNTER-1))
        done

        echo
        COUNTER=12
        YEAR=2017
        until [ $COUNTER == 0 ]; do
            NUMBER_OF_STAKES=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$COUNTER\", \"to\":\"$YEAR-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.records)
            STAKE_AMOUNT=$( $GHOST_CLI filtertransactions "{\"from\":\"$YEAR-$COUNTER\", \"to\":\"$YEAR-$COUNTER\",\"count\":100000,\"category\":\"stake\",\"collate\":true,\"include_watchonly\":true,\"with_reward\":true}" | jq .collated.total_reward)
            if [[ $NUMBER_OF_STAKES != 0 ]] && [[ $STAKE_AMOUNT != 0 ]]; then
                printf '%-4s %-15s %-30s %-12s\n' \
                "${messages["stakingnode_stats_indent"]}" "$COUNTER ($YEAR)" "$NUMBER_OF_STAKES" "$STAKE_AMOUNT"
            fi
            COUNTER=$((COUNTER-1))
        done

    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi

}

stakingnode_proposallist(){

    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            ok "${messages["done"]}"
        else
            die "\n - no wallet exists, please type 'ghostman stakingnode init' ${messages["exiting"]}"
        fi
        # TODO: Create proposals repo
        PROPOSAL_DOWNLOAD_URL="https://raw.githubusercontent.com/ghost-coin/ghost-proposals/master/testnet/metadata.txt"
        echo

        pending " --> ${messages["proposal_get_active"]}"
        $wget_cmd -O - $PROPOSAL_DOWNLOAD_URL | pv -trep -s27M -w80 -N proposal > "proposal"
        if [ ! -e "proposal" ] ; then
            echo -e "${C_RED}error ${messages["downloading"]} file"
            echo -e "tried to get $PROPOSAL_DOWNLOAD_URL$C_NORM"
            exit 1
        else
        ok "${messages["done"]}"
        fi

        pending " --> ${messages["proposal_reading"]}"
        PROPOSALLIST=$( cat proposal | jq -r .);

        if [ -z "$PROPOSALLIST" ]; then
           rm -rf proposal
           die "\n - failed to get proposal list ${messages["exiting"]}"
        fi
        ok "${messages["done"]}"

        pending " --> ${messages["proposal_process"]}"
        ok "${messages["done"]}"

        echo
        #PROCESSPROPOSALLIST=$( echo $PROPOSALLIST | jq -r '. | "\(.proposalid)\t\(.name)\t\(.blockheight_start)\t\(.blockheight_end)\t\(.link)"');
        #PROCESSPROPOSALLIST=$( echo $PROPOSALLIST | jq -r '(.[0] |keys_unsorted | @tsv), (.[]|.|map(.) |@tsv)' | column -t);
        printf '%s\n' "$PROPOSALLIST"

    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi

}

stakingnode_proposalvote(){

    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            ok "${messages["done"]}"
        else
            die "\n - no wallet exists, please type 'ghostman stakingnode init' ${messages["exiting"]}"
        fi

        if [ ! -e "proposal" ] ; then
            die "\n - no proposal data exists, please type 'ghostman proposal list' ${messages["exiting"]}"
        fi

        echo
        highlight "Setting a new vote will clear all previous settings. You can only vote on one proposal at a time."
        echo
        pending "Continue to set a new vote?"
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi

        echo
        pending "Proposal ID : "
        read -r proposalid

        pending "checking if valid proposal ... "
        PROPOSAL_HEIGHT_START=$( cat proposal | jq ".[] | select(.proposalid == ${proposalid} ) | .blockheight_start" )
        PROPOSAL_HEIGHT_END=$( cat proposal | jq ".[] | select(.proposalid == ${proposalid} ) | .blockheight_end" )

        if [ -z "$PROPOSAL_HEIGHT_START" ]; then
            die "\n - not a valid proposal id! ' ${messages["exiting"]}"
        fi

        GHOSTD_CURRENT_BLOCK=$("$GHOST_CLI" getblockcount 2>/dev/null)
        if [ -z "$GHOSTD_CURRENT_BLOCK" ] ; then GHOSTD_CURRENT_BLOCK=0 ; fi

        if [ "$GHOSTD_CURRENT_BLOCK" -gt "$PROPOSAL_HEIGHT_END" ]; then
            die "\n - proposal voting has finished! ' ${messages["exiting"]}"
        fi

        ok "${messages["done"]}"

        PROPOSALDETAILS=$( cat proposal | jq ".[] | select(.proposalid == ${proposalid} ) | ." )
        printf '%s\n' "$PROPOSALDETAILS"

        echo
        pending "Abstain (0), Vote For (1) or Vote Against (2) [default=0]: "
        read -r proposaloption

        if [ -z "$proposaloption" ]; then
            proposaloption=0
        fi

        if [ "$proposaloption" == 0 ]; then
            proposalid=0
        fi

        if "$GHOST_CLI" setvote "$proposalid" "$proposaloption" "$PROPOSAL_HEIGHT_START" "$PROPOSAL_HEIGHT_END"; then
            ok ""
        else
            die "\n - error setting vote! ' ${messages["exiting"]}"
	fi

    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi

}

stakingnode_proposaltally(){

    if [ $GHOSTD_RUNNING == 1 ] && [ "$GHOSTD_WALLETSTATUS" != "Locked" ]; then
        pending " --> ${messages["stakingnode_init_walletcheck"]}"
        if [ ! "$GHOSTD_WALLET"  == "null" ]; then
            ok "${messages["done"]}"
        else
            die "\n - no wallet exists, please type 'ghostman stakingnode init' ${messages["exiting"]}"
        fi

        if [ ! -e "proposal" ] ; then
            die "\n - no proposal data exists, please type 'ghostman proposal list' ${messages["exiting"]}"
        fi

        echo
        pending "Proposal ID : "
        read -r proposalid

        pending "checking if valid proposal ... "
        PROPOSAL_HEIGHT_START=$( cat proposal | jq ".[] | select(.proposalid == ${proposalid} ) | .blockheight_start" )
        PROPOSAL_HEIGHT_END=$( cat proposal | jq ".[] | select(.proposalid == ${proposalid} ) | .blockheight_end" )

        if [ -z "$PROPOSAL_HEIGHT_START" ]; then
            die "\n - not a valid proposal id! ' ${messages["exiting"]}"
        fi

        ok "${messages["done"]}"
        PROPOSALDETAILS=$( cat proposal | jq ".[] | select(.proposalid == ${proposalid} ) | ." )
        printf '%s\n' "$PROPOSALDETAILS"


        pending "checking blockchain for voting data ... "
        echo
        if "$GHOST_CLI" tallyvotes "$proposalid" "$PROPOSAL_HEIGHT_START" "$PROPOSAL_HEIGHT_END"; then
            ok ""
        else
            die "\n - error getting vote details! ' ${messages["exiting"]}"
        fi

    else
        die "\n - wallet is locked! Please unlock first. ${messages["exiting"]}"
    fi

}
configure_firewall(){

    UFW_STATUS=$(sudo ufw status | head -n 1 | cut -d' ' -f2)
    pending " --> ${messages["firewall_status"]}"
    ok " $UFW_STATUS"

    if [ "$UFW_STATUS" == "inactive" ]; then
        echo
        pending "Configure default firewall?"
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi

        pending " --> ${messages["firewall_configure"]}"
        echo
        SSH_PORT=${SSH_CLIENT##* }
        if [ -z "$SSH_PORT" ] ; then SSH_PORT=22 ; fi

        # creates a minimal set of firewall rules that allows INBOUND masternode p2p & SSH ports */
        # disallow everything except ssh, 8080 (webserver) and inbound ports 51728 and 51938
        $FIREWALL_CLI default deny
        $FIREWALL_CLI logging on
        $FIREWALL_CLI allow $SSH_PORT/tcp
        $FIREWALL_CLI allow 8080/tcp comment 'ghostman webserver'
        $FIREWALL_CLI allow 51728/tcp comment 'ghost p2p mainnet'
        $FIREWALL_CLI allow 51938/tcp comment 'ghost p2p testnet'

        # This will only allow 6 connections every 30 seconds from the same IP address.
        $FIREWALL_CLI limit OpenSSH
        $FIREWALL_CLI --force enable
        ok "${messages["done"]}"
    fi

        pending " --> ${messages["firewall_report"]}"
        echo
        $FIREWALL_CLI status
}

firewall_reset(){

    UFW_STATUS=$(sudo ufw status | head -n 1 | cut -d' ' -f2)
    pending " --> ${messages["firewall_status"]}"
    ok " $UFW_STATUS"

    if [ "$UFW_STATUS" == "active" ]; then
        echo
        pending "Reset and disable firewall?"
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi

        ok ""
        echo "y" | $FIREWALL_CLI reset
        UFW_STATUS=$(sudo ufw status | head -n 1 | cut -d' ' -f2)
        pending " --> ${messages["firewall_status"]}"
        ok " $UFW_STATUS"
    fi
}

_get_ghostd_proc_status(){
    GHOSTD_HASPID=0
    if [ -e "$INSTALL_DIR/ghost.pid" ] ; then
        GHOSTD_HASPID=$(ps --no-header "$(cat "$INSTALL_DIR/ghost.pid" 2>/dev/null)" | wc -l);
    else
        if ! GHOSTD_HASPID=$(pidof "$INSTALL_DIR/ghostd"); then
            GHOSTD_HASPID=0
        fi
    fi
    GHOSTD_PID=$(pidof "$INSTALL_DIR/ghostd")
}

get_ghostd_status(){

    _get_ghostd_proc_status

    GHOSTD_UPTIME=$($GHOST_CLI uptime 2>/dev/null)
    if [ -z "$GHOSTD_UPTIME" ] ; then GHOSTD_UPTIME=0 ; fi

    GHOSTD_LISTENING=$(netstat -nat | grep LIST | grep -c 51728);
    GHOSTD_CONNECTIONS=$(netstat -nat | grep ESTA | grep -c 51728);
    GHOSTD_CURRENT_BLOCK=$("$GHOST_CLI" getblockcount 2>/dev/null)
    if [ -z "$GHOSTD_CURRENT_BLOCK" ] ; then GHOSTD_CURRENT_BLOCK=0 ; fi


    WEB_BLOCK_COUNT_GHOST=$($curl_cmd https://ghostscan.io/ghost-insight-api/sync 2>/dev/null | jq -r .blockChainHeight)
    if [ -z "$WEB_BLOCK_COUNT_GHOST" ]; then
        WEB_BLOCK_COUNT_GHOST=0
    fi

    GHOSTD_SYNCED=0
    if [ $GHOSTD_RUNNING == 1 ]; then
        if [ $GHOSTD_CURRENT_BLOCK == $WEB_BLOCK_COUNT_GHOST ] || [ $GHOSTD_CURRENT_BLOCK -ge $((WEB_BLOCK_COUNT_CHAINZ -5)) ] || [ $GHOSTD_CURRENT_BLOCK -ge $((WEB_BLOCK_COUNT_GHOST -5)) ]; then
            GHOSTD_SYNCED=1
        fi
    fi

    GHOSTD_CONNECTED=0
    if [ "$GHOSTD_CONNECTIONS" -gt 0 ]; then GHOSTD_CONNECTED=1 ; fi

    GHOSTD_UP_TO_DATE=0
    if [ -z "$LATEST_VERSION" ]; then
        GHOSTD_UP_TO_DATE_STATUS="UNKNOWN"
    else
        GHOSTD_UP_TO_DATE_STATUS="NO"
        if [ "$LATEST_VERSION" == "$CURRENT_VERSION" ]; then
            GHOSTD_UP_TO_DATE=1
        fi
    fi

    get_public_ips

    PUBLIC_PORT_CLOSED=$( timeout 2 nc -4 -z "$PUBLIC_IPV4" 51728 > /dev/null 2>&1; echo $? )

    #staking info
    if [ $GHOSTD_RUNNING == 1 ]; then
        GHOSTD_GETSTAKINGINFO=$($GHOST_CLI getstakinginfo 2>/dev/null);
        STAKING_ENABLED=$(echo "$GHOSTD_GETSTAKINGINFO" | grep enabled | awk '{print $2}' | sed -e 's/[",]//g')
        if [ "$STAKING_ENABLED" == "true" ]; then STAKING_ENABLED=1; elif [ $STAKING_ENABLED == "false" ]; then STAKING_ENABLED=0; fi
        STAKING_CURRENT=$(echo "$GHOSTD_GETSTAKINGINFO" | grep staking | awk '{print $2}' | sed -e 's/[",]//g')
        if [ "$STAKING_CURRENT" == "true" ]; then STAKING_CURRENT=1; elif [ $STAKING_CURRENT == "false" ]; then STAKING_CURRENT=0; fi
        STAKING_STATUS=$(echo "$GHOSTD_GETSTAKINGINFO" | grep cause | awk '{print $2}' | sed -e 's/[",]//g')
        STAKING_PERCENTAGE=$(echo "$GHOSTD_GETSTAKINGINFO" | grep percentyearreward | awk '{print $2}' | sed -e 's/[",]//g')
        STAKING_DIFF=$(echo "$GHOSTD_GETSTAKINGINFO" | grep difficulty | awk '{print $2}' | sed -e 's/[",]//g')
        GHOSTD_STAKEWEIGHT=$(echo "$GHOSTD_GETSTAKINGINFO" | grep "\"weight"\" | awk '{print $2}' | sed -e 's/[",]//g')
        GHOSTD_NETSTAKEWEIGHT=$(echo "$GHOSTD_GETSTAKINGINFO" | grep netstakeweight | awk '{print $2}' | sed -e 's/[",]//g')

        GHOSTD_NETSTAKEWEIGHT=$((GHOSTD_NETSTAKEWEIGHT / 100000000))
        GHOSTD_STAKEWEIGHT=$((GHOSTD_STAKEWEIGHT / 100000000))

        #Hack for floating point arithmetic
        STAKEWEIGHTPERCENTAGE=$( awk "BEGIN {printf \"%.3f%%\", $GHOSTD_STAKEWEIGHT/$GHOSTD_NETSTAKEWEIGHT*100}" )
        T_GHOSTD_STAKEWEIGHT=$(printf "%'.0f" $GHOSTD_STAKEWEIGHT)
        GHOSTD_STAKEWEIGHTLINE="$T_GHOSTD_STAKEWEIGHT ($STAKEWEIGHTPERCENTAGE)"

        GHOSTD_GETCOLDSTAKINGINFO=$($GHOST_CLI getcoldstakinginfo 2>/dev/null);
        CSTAKING_ENABLED=$(echo "$GHOSTD_GETCOLDSTAKINGINFO" | grep enabled | awk '{print $2}' | sed -e 's/[",]//g')
        CSTAKING_CURRENT=$(echo "$GHOSTD_GETCOLDSTAKINGINFO" | grep currently_staking | awk '{print $2}' | sed -e 's/[",]//g')
        CSTAKING_BALANCE=$(echo "$GHOSTD_GETCOLDSTAKINGINFO" | grep coin_in_coldstakeable_script | awk '{print $2}' | sed -e 's/[",]//g')
    fi
}

date2stamp () {
    date --utc --date "$1" +%s
}

stamp2date (){
    date --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}

dateDiff (){
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    dte1=$(date2stamp "$1")
    dte2=$(date2stamp "$2")
    diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    echo $((diffSec*abs/sec))
}

function displaytime()
{
    local t=$1

    local d=$((t/60/60/24))
    local h=$((t/60/60%24))
    local m=$((t/60%60))
    local s=$((t%60))

    if [[ $d -gt 0 ]]; then
            [[ $d = 1 ]] && echo -n "$d day " || echo -n "$d days "
    fi
    if [[ $h -gt 0 ]]; then
            [[ $h = 1 ]] && echo -n "$h hour " || echo -n "$h hours "
    fi
    if [[ $m -gt 0 ]]; then
            [[ $m = 1 ]] && echo -n "$m minute " || echo -n "$m minutes "
    fi
    if [[ $d = 0 && $h = 0 && $m = 0 ]]; then
            [[ $s = 1 ]] && echo -n "$s second" || echo -n "$s seconds"
    fi
    echo
}

get_host_status(){
    HOST_LOAD_AVERAGE=$(< /proc/loadavg awk '{print $1" "$2" "$3}')
    uptime=$(</proc/uptime)
    uptime=${uptime%%.*}
    HOST_UPTIME_DAYS=$(( uptime/60/60/24 ))
    HOSTNAME=$(hostname -f)
}


print_getinfo() {

    if [ $GHOSTD_RUNNING == 1 ]; then
        $GHOST_CLI -getinfo
        $GHOST_CLI getwalletinfo
    fi
}

print_status() {

    pending "${messages["status_hostnam"]}" ; ok "$HOSTNAME"
    pending "${messages["status_uptimeh"]}" ; ok "$HOST_UPTIME_DAYS ${messages["days"]}, $HOST_LOAD_AVERAGE"
    pending "${messages["status_ghostdip"]}" ; if [ "$PUBLIC_IPV4" != "none" ] ; then ok "$PUBLIC_IPV4" ; else err "$PUBLIC_IPV4" ; fi
    pending "${messages["status_ghostdve"]}" ; ok "$CURRENT_VERSION"
    pending "${messages["status_uptodat"]}" ; if [ "$GHOSTD_UP_TO_DATE"      -gt 0 ] ; then ok "${messages["YES"]}" ; else err "$GHOSTD_UP_TO_DATE_STATUS ($LATEST_VERSION)" ; fi
    pending "${messages["status_running"]}" ; if [ "$GHOSTD_HASPID"          -gt 0 ] ; then ok "${messages["YES"]}" ; else err "${messages["NO"]}" ; fi
    pending "${messages["status_uptimed"]}" ; if [ "$GHOSTD_UPTIME"          -gt 0 ] ; then ok "$(displaytime $GHOSTD_UPTIME)" ; else err "${messages["NO"]}" ; fi
    pending "${messages["status_drespon"]}" ; if [ "$GHOSTD_RUNNING"         -gt 0 ] ; then ok "${messages["YES"]}" ; else err "${messages["NO"]}" ; fi
    pending "${messages["status_dlisten"]}" ; if [ "$GHOSTD_LISTENING"       -gt 0 ] ; then ok "${messages["YES"]}" ; else err "${messages["NO"]}" ; fi
    pending "${messages["status_dportop"]}" ; if [ "$PUBLIC_PORT_CLOSED"     -lt 1 ] ; then ok "${messages["YES"]}" ; else highlight "${messages["NO"]}*" ; fi
    pending "${messages["status_dconnec"]}" ; if [ "$GHOSTD_CONNECTED"       -gt 0 ] ; then ok "${messages["YES"]}" ; else err "${messages["NO"]}" ; fi
    pending "${messages["status_dconcnt"]}" ; if [ "$GHOSTD_CONNECTIONS"     -gt 0 ] ; then ok "$GHOSTD_CONNECTIONS" ; else err "$GHOSTD_CONNECTIONS" ; fi
    pending "${messages["status_dblsync"]}" ; if [ "$GHOSTD_SYNCED"          -gt 0 ] ; then ok "${messages["YES"]}" ; else err "${messages["NO"]}" ; fi
    pending "${messages["status_dbllast"]}" ; if [ "$GHOSTD_SYNCED"          -gt 0 ] ; then ok "$GHOSTD_CURRENT_BLOCK" ; else err "$GHOSTD_CURRENT_BLOCK" ; fi
    pending "${messages["status_webghost"]}" ; if [ "$WEB_BLOCK_COUNT_GHOST" -gt 0 ] ; then ok "$WEB_BLOCK_COUNT_GHOST" ; else err "$WEB_BLOCK_COUNT_GHOST" ; fi
    if [ "$GHOSTD_RUNNING" -gt 0 ]; then
        pending "${messages["breakline"]}" ; ok ""
        pending "${messages["status_stakeen"]}" ; if [ $STAKING_ENABLED -gt 0 ] ; then ok "${messages["YES"]} - $STAKING_PERCENTAGE%" ; else err "${messages["NO"]}" ; fi
        pending "${messages["status_stakedi"]}" ; ok "$(printf "%'.0f" "$STAKING_DIFF")"
        pending "${messages["status_stakenw"]}" ; ok "$(printf "%'.0f" "$GHOSTD_NETSTAKEWEIGHT")"
        pending "${messages["breakline"]}" ; ok ""
        pending "${messages["status_stakecu"]}" ; if [ $STAKING_CURRENT -gt 0 ] ; then ok "${messages["YES"]}" ; else err "${messages["NO"]} - $STAKING_STATUS" ; fi
        pending "${messages["status_stakeww"]}" ; ok "$GHOSTD_STAKEWEIGHTLINE"
        pending "${messages["status_stakebl"]}" ; ok "$(printf "%'.0f" "$CSTAKING_BALANCE")"
    fi

    if [ "$PUBLIC_PORT_CLOSED"  -gt 0 ]; then
       echo
       highlight "* Inbound P2P Port is not open - this is okay and will not affect the function of this staking node."
       highlight "  However by opening port 51728/tcp you can provide full resources to the Ghost Network by acting as a 'full node'."
       highlight "  A 'full staking node' will increase the number of other nodes you connect to beyond the 16 limit."
    fi
}

show_message_configure() {
    echo
    ok "${messages["to_start_ghost"]}"
    echo
    echo -e "    ${C_YELLOW}ghostman restart now$C_NORM"
    echo
}

get_public_ips() {
    PUBLIC_IPV4=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)
}

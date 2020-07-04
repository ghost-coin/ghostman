#!/usr/bin/env bash

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
sudo apt update
sudo apt-get install python git unzip pv jq dnsutils

# load common functions ------------------------------------------------------
UNATTENDED=1
bash bin/ghostman.sh install
bash bin/ghostman.sh restart now
## Add crontab to try updating each day
cat > mycron << EOL
0 0 * * * cd $HOME/ghostman  && bash bin/ghostman.sh update >> ./tmp/update.log 2>&1
EOL
crontab mycron
rm -f mycron
bash bin/ghostman.sh stakingnode init
bash bin/ghostman.sh stakingnode new



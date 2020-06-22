#!/bin/bash

GHOSTMAN_PATH=~/ghostman
GHOST_PATH=~/ghostcore
HTML_PATH=$GHOSTMAN_PATH/webserver/public_html

"$GHOSTMAN_PATH"/ghostman status > "$HTML_PATH"/ghostman-status.tmp
"$GHOSTMAN_PATH"/ghostman stakingnode stats >> "$HTML_PATH"/ghostman-status.tmp
"$GHOST_PATH"/ghost-cli getwalletinfo | grep watchonly >> "$HTML_PATH"/ghostman-status.tmp

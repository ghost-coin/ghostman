# ghostman

Ghost wallet/daemon management utilities - version 0.11 based on partyman from Particl

* This script installs, updates, and manages single-user ghost daemons and wallets
* This script provides the ability to create a new wallet and manage staking node (cold staking functionality)

# Install/Usage

To install ghostman do:

    sudo apt-get install python git unzip pv jq dnsutils
    cd ~ && git clone https://github.com/ghost-coin/ghostman

To get the current status of ghostd, do:

    ghostman/ghostman status

To get the RPC command `getinfo` and `getwalletinfo` from ghostd, do:

    ghostman/ghostman getinfo



To perform a new install of ghost, do:

    ghostman/ghostman install

To update to the latest version of ghost, do:

    ghostman/ghostman update

To overwrite an existing ghost install, do:

    ghostman/ghostman reinstall

To restart (or start) ghostd, do:

    ghostman/ghostman restart



To create a new wallet on this staking node, do:

    ghostman/ghostman stakingnode init

To create a new public key on this staking node, do:

    ghostman/ghostman stakingnode new

To get a list of public keys on this staking node, do:

    ghostman/ghostman stakingnode

To get staking stats for this staking node, do:

    ghostman/ghostman stakingnode stats

To configure the reward address for this staking node, do:

    ghostman/ghostman stakingnode rewardaddress

To configure the smsg fee rate target for this staking node, do:

    ghostman/ghostman stakingnode smsgfeeratetarget



To install an create firewall/ufw rules to restrict access to only PORTS 22, 8080, 51738 and 51938, do:

    ghostman/ghostman firewall

To disable the firewall/ufw and reset the rules, do:

    ghostman/ghostman firewall reset



# Commands

## install

"ghostman install" downloads and initializes a fresh ghost install into ~/.ghost
unless already present

## reinstall

"ghostman reinstall" downloads and overwrites existing ghost executables, even if
already present

## restart

"ghostman restart [now]" restarts (or starts) ghostd. Searches for ghost-cli/ghostd
the current directory, ~/.ghost, and $PATH. It will prompt to restart if not
given the optional 'now' argument.

## status

"ghostman status" interrogates the locally running ghostd and displays its status

# Dependencies

* bash version 4
* nc (netcat)
* curl
* perl
* pv
* python
* unzip
* jq
* ghostd, ghost-cli
* dnsutils

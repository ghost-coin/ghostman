The below text contains instructions on how to get a ghost node running with the help of ghostman
## Inital Steps
- First install the pre-requisites on a Ubuntu VPS running version 19 or above.
    ```console
    sudo apt-get install python git unzip pv jq dnsutils
    cd ~ && git clone https://github.com/ghost-coin/ghostman
    ```
- Next install ghostman via
    ```console
    bash ghostman/bin/ghostman.sh install
    ```

## Steps to setup coldstaking node on vps or rpi
Once ghostman has installed and started ghost daemon,we can use ghost-cli directly.
- Initialize a staking node with
    ```console
        bash ghostman/bin/ghostman.sh stakingnode init
    ```
- Make sure to write down the words,we will need this to restore the wallet later on on desktop to keep track of staking rewards and sending out coins from stake rewards.The mnemonic is the private master key to the coins in that node.
Output will be simmilar to this
    ```console
    $ bash ghostman/bin/ghostman.sh stakingnode init
    ghostman version 0.12 - Thu Jun 25 17:27:30 UTC 2020
    gathering info, please wait...   done!
    null
    --> checking wallet ...  done!
    --> recovery phrase : joy horror plastic sleep noble material space foil swift wrist creek chicken soap return valley royal merry make force device brown skin grain remove
    Have you written down your recovery phrase?
    [y/N] y
    --> creating wallet ...  done!
    ghostman stakingnode info
    ```
- Now generate a coldstaking ext key via
    ```console
        bash ghostman/bin/ghostman.sh stakingnode new
    ```
- Copy the given extkey and paste it in the cold staking key in ghost desktop.

- To fast forward the delegation process click zap and follow the instructions.Once done and cold staking progress is at 100%,you can close the wallet on the PC/Desktop.
- Now you can earn stakes without needing to keep the desktop on 24/7.

## Steps to hot-stake on vps
Once ghostman has installed and started ghost daemon,we can use ghost-cli directly.
- Initialize a staking node with
    ```console
        bash ghostman/bin/ghostman.sh stakingnode init
    ```
- Make sure to write down the words,we will need this to restore the wallet later on on desktop to keep track of staking rewards and sending out coins from stake rewards.The mnemonic is the private master key to the coins in that node.
Output will be simmilar to this
    ```console
    $ bash ghostman/bin/ghostman.sh stakingnode init
    ghostman version 0.12 - Thu Jun 25 17:27:30 UTC 2020
    gathering info, please wait...   done!
    null
    --> checking wallet ...  done!
    --> recovery phrase : joy horror plastic sleep noble material space foil swift wrist creek chicken soap return valley royal merry make force device brown skin grain remove
    Have you written down your recovery phrase?
    [y/N] y
    --> creating wallet ...  done!
    ghostman stakingnode info
    ```
- To get a ghost address to send funds to use
    ```console
        ghost-cli getnewaddress
    ```
This will give you a public address to send GHOST to.
- Once you send your ghost to this address to confirm the node has recived the coins,execute:
    ```console
        ghost-cli listtransactions
    ```
You should see a tx with the coins you sent returned.

To view rewards and send out rewards easily restore the mnemonic as a new wallet in ghost desktop.
The below text contains instructions on how to get a ghost node running with the help of ghostman
## Inital Steps
- First install the pre-requisites on a Ubuntu VPS running version 19 or above.
    ```bash
    sudo apt-get install python git unzip pv jq dnsutils
    cd ~ && git clone https://github.com/ghost-coin/ghostman
    ```
- Next install ghostman via
    ```bash
    ghostman/ghostman install
    ```
## Steps to hot-stake on vps
Once ghostman has installed and started ghost daemon,we can use ghost-cli directly.
- Initialize a staking node with
    ```bash
        bash bin/ghostman.sh stakingnode init
    ```
- Make sure to write down the words,we will need this to restore the wallet later on on desktop to keep track of staking rewards and sending out coins from stake rewards.The mnemonic is the private master key to the coins in that node.
Output will be simmilar to this
```bash
$ bash bin/ghostman.sh stakingnode init
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
    ```bash
        ghost-cli getnewaddress
    ```
This will give you a public address to send GHOST to.
- Once you send your ghost to this address to confirm the node has recived the coins,execute:
    ```bash
        ghost-cli listtransactions
    ```
You should see a tx with the coins you sent returned.

To view rewards and send out rewards easily restore the mnemonic as a new wallet in ghost desktop.
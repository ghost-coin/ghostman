
#echo "en_US"

messages=(

    ["ghostman_version"]="ghostman version"
    ["gathering_info"]="gathering info, please wait... "
    ["done"]=" done!"
    ["exiting"]="Exiting."

    ["days"]="days"
    ["hours"]="hours"
    ["mins"]="mins"
    ["secs"]="secs"

    ["YES"]="YES"
    ["NO"]="NO"
    ["FAILED"]="FAILED!"

    ["not_implemented"]="This feature is not implemented!"
    ["prompt_are_you_sure"]="Are you sure?"
    ["prompt_ipv4_ipv6"]="Host has both ipv4 and ipv6 addresses.\n - Use ipv6 for install?"

    ["download"]="download"
    ["downloading"]="Downloading"
    ["creating"]="Creating"
    ["checksum"]="checksum"
    ["checksumming"]="Checksumming"
    ["unpacking"]="Unpacking"
    ["stopping"]="Stopping"
    ["removing_old_version"]="Removing old version... "
    ["please_wait"]="Please wait..."
    ["try_again_later"]="Try again later."
    ["launching"]="Launching"
    ["bootstrapping"]="Bootstrapping"
    ["unzipping"]="Unzipping"
    ["waiting_for_ghostd_to_respond"]="Waiting for ghostd to respond... "
    ["deleting_cache_files"]="Deleting cache files, debug.log... "
    ["starting_ghostd"]="Starting ghostd... "

    ["err_downloading_file"]="error downloading file"
    ["err_tried_to_get"]="tried to get"
    ["err_no_pkg_mgr"]="cannot determine platform/package manager"
    ["err_no_pkg_mgr_install_failed"]="installing dependency from package manager failed"
    ["err_missing_dependency"]="missing dependency:"
    ["err_unknown_platform"]="unknown platform:"
    ["err_ghostman_supports"]="ghostman currently supports 32/64bit linux and 32/64bit arm/aarch"
    ["err_could_not_get_version"]="Could not find latest version from"
    ["err_failed_ip_resolve"]="failed to resolve public ip. retrying... "

    ["newer_ghost_available"]="a newer version of ghost is available."
    ["successfully_upgraded"]="ghost successfully upgraded to version"
    ["successfully_installed"]="successfully installed!"
    ["installed_in"]="Installed in"
    ["ghost_version"]="ghost version"
    ["is_not_uptodate"]="is not up to date."
    ["is_uptodate"]="is up to date."
    ["preexisting_dir"]="pre-existing directory"
    ["run_reinstall"]="Run 'ghostman reinstall' to overwrite."
    ["reinstall_to"]="reinstall to"
    ["and_install_to"]="and install to"

    ["exec_found_in_system_dir"]="ghost executables found in system dir"
    ["run_ghostman_as_root"]=". Run ghostman as root (sudo ghostman command) to continue."
    ["ghostd_not_found"]="ghostd not found in"
    ["ghostcli_not_found"]="ghost-cli not found in"
    ["ghostcli_not_found_in_cwd"]="cannot find ghost-cli in current directory"

    ["sync_to_github"]="sync ghostman to github now?"

    ["usage"]="USAGE"
    ["commands"]="COMMANDS"
    ["usage_title"]="installs, updates, and manages single-user ghost daemons and wallets"
    ["usage_install_description"]="installs, updates, and manages single-user ghost daemons and wallets"
    ["usage_update_description"]="updates ghost to latest version and restarts"
    ["usage_restart_description"]="restarts ghostd and deletes:"
    ["usage_restart_description_now"]="will prompt user if not given the 'now' argument"
    ["usage_status_description"]="polls local and web sources and displays current status"
    ["usage_sync_description"]="updates ghostman to latest github version"
    ["usage_branch_description"]="switch ghostman to an alternate/experimental github branch"
    ["usage_reinstall_description"]="overwrites ghost with latest version and restarts"
    ["usage_version_description"]="prints ghostmans version number and exits"
    ["usage_stakingnode_description"]="displays current public keys on this staking nodes ghost daemon"
    ["usage_stakingnode_init_description"]="[init] creates a new wallet"
    ["usage_stakingnode_new_description"]="[new] creates a new public key to use with your cold staking wallet"
    ["usage_stakingnode_stats_description"]="[stats] shows stakingnode earnings"
    ["usage_stakingnode_rewardaddress_description"]="[rewardaddress] configure ghost address for staking rewards"
    ["usage_stakingnode_smsgfeeratetarget_description"]="[smsgfeeratetarget] configure smsg fee rate target"
    ["usage_stakingnode_info_description"]="[info] shows all public keys created for cold staking"

    ["usage_firewall_description"]="installs and configures the UFW firewall and allows ports 22,8080,51728 and 51938"
    ["usage_firewall_reset"]="disables the UFW firewall and resets the rules to default"


    ["to_start_ghost"]="To start ghostd run:"

    ["quit_uptodate"]="Up to date."

    ["requires_updating"]="requires updating. Latest version is:"
    ["requires_sync"]="Do 'git pull' manually or download the latest version."

    ["no_forks_detected"]="no forks detected"

    # space aligned strings. pay attention to spaces!
    ["currnt_version"]="  current version: "
    ["latest_version"]="   latest version: "

    ["status_hostnam"]="  hostname                         : "
    ["status_uptimeh"]="  host uptime/load average         : "
 ["status_ghostdip"]="  ghostd bind ip address         : "
 ["status_ghostdve"]="  ghostd version                 : "
    ["status_uptodat"]="  ghostd up-to-date              : "
    ["status_running"]="  ghostd running                 : "
    ["status_uptimed"]="  ghostd uptime                  : "
    ["status_drespon"]="  ghostd responding        (RPC) : "
    ["status_dlisten"]="  ghostd listening          (IP) : "
    ["status_dportop"]="  ghostd port open   (P2P 51728) : "
    ["status_dconnec"]="  ghostd connecting      (peers) : "
    ["status_dconcnt"]="  ghostd connection count        : "
    ["status_dblsync"]="  ghostd blocks synced           : "
    ["status_dbllast"]="  last block      (local ghostd) : "
    ["status_webghost"]="             (ghostscan.io) : "
    ["status_webchai"]="                          (chainz) : "

    ["status_dcurdif"]="  ghostd current network diff    : "



    ["status_stakeen"]="  ghostd staking enabled         : "
    ["status_stakecu"]="  ghostd staking currently?      : "
    ["status_stakedi"]="  ghostd staking difficulty      : "
    ["status_stakenw"]="  ghostd staking network weight  : "
    ["status_stakeww"]="  ghostd staking wallet weight   : "
    ["status_stakebl"]="  ghostd coldstaking balance     : "

    ["ago"]=" ago"
    ["found"]="found."
    ["breakline"]=""

    ["stakingnode_init_walletcheck"]="checking wallet ... "
    ["stakingnode_init_walletgenerate"]="recovery phrase : "
    ["stakingnode_init_walletcreate"]="creating wallet ... "
    ["stakingnode_new_publickey"]="creating new cold staking public key ... "
    ["stakingnode_reward_check"]="checking for existing reward address config ... "
    ["stakingnode_reward_address"]="configuring reward address ... "
    ["stakingnode_reward_found"]="Current Reward Address : "
    ["stakingnode_smsgfeerate_check"]="checking for existing smsg fee rate target config ... "
    ["stakingnode_smsgfeerate_address"]="configuring smsg fee rate target ... "
    ["stakingnode_smsgfeerate_found"]="Current smsg fee rate target : "

    ["stakingnode_stats_daily"]="getting stats for current month ... "
    ["stakingnode_stats_monthly"]="getting stats for entire year ... "
    ["stakingnode_stats_indent"]="   "

    ["firewall_status"]="checking status of firewall ..."
    ["firewall_configure"]="configuring firewall ..."
    ["firewall_report"]="generating firewall status report ..."

    ["no_python_fallback"]="Python not found, attempting fallback method to determine package manager."

    ["proposal_get_active"]="getting active proposals ... "
    ["proposal_process"]="processing proposals ... "
    ["proposal_reading"]="reading proposal data ... "
)

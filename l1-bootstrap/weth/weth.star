# Bootstrap WETH
#
# Uses a Foundry script to deposit Ether into WETH for each account.

def bootstrap(plan, config, el_context):
    """
    Deposit Ether into WETH for all accounts using a Foundry script.

    Each account deposits one Ether to receive WETH.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: Execution layer context (for RPC endpoint).
    """

    # Get pre-built artifacts from L1 deployment (contracts.star).
    src_artifact = plan.get_files_artifact("contracts-src")
    script_artifact = plan.get_files_artifact("contracts-script")
    foundry_artifact = plan.get_files_artifact("contracts-foundry-toml")
    lib_artifact = plan.get_files_artifact("contracts-lib")

    # Run WETH deposit via Foundry script.
    rpc_url = "http://{}:{}".format(
        el_context.service.ip_address,
        config["port_el_rpc_http"],
    )
    plan.run_sh(
        name="deposit-weth",
        description="Depositing Ether into WETH for {} accounts".format(
            len(config["accounts"]),
        ),
        image=config["foundry_image"],
        files={
            "/mnt/src": src_artifact,
            "/mnt/script": script_artifact,
            "/mnt/config": foundry_artifact,
            "/mnt/lib": lib_artifact,
        },
        env_vars={
            "FOUNDRY_DISABLE_NIGHTLY_WARNING": "1",
            "MNEMONIC": config["mnemonic"],
            "NUM_ACCOUNTS": str(len(config["accounts"])),
        },
        run=(
            "mkdir -p /tmp/contracts && " +
            "cp -r /mnt/src /tmp/contracts/src && " +
            "cp -r /mnt/script /tmp/contracts/script && " +
            "cp -r /mnt/lib /tmp/contracts/dependencies && " +
            "cp /mnt/config/foundry.toml /tmp/contracts/foundry.toml && " +
            "cd /tmp/contracts && " +
            "forge script script/DepositWETH.s.sol:DepositWETH " +
            "--rpc-url {} --broadcast --non-interactive -vvv".format(rpc_url)
        ),
    )

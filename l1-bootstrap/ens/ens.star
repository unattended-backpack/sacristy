# Bootstrap ENS
#
# Uses a Foundry script to register ENS names via multicall.
# Accounts must have EIP-7702 delegation set up before running this.

def bootstrap(plan, config, el_context):
    """
    Register ENS names for all accounts using a Foundry script.

    Requires:
        - L1 must be deployed (contracts already compiled)
        - EIP-7702 delegation must be set up first via delegate.setup()

    Each account calls its multicall() to batch all 6 ENS operations
    into a single transaction.

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

    # Build the names list (semicolon-separated).
    names = ";".join([acct["name"] for acct in config["accounts"]])

    # Run ENS registration via Foundry script.
    rpc_url = "http://{}:{}".format(
        el_context.service.ip_address,
        config["port_el_rpc_http"],
    )
    plan.run_sh(
        name="register-ens-names",
        description="Registering {} ENS names via multicall".format(len(config["accounts"])),
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
            "NAMES": names,
        },
        run=(
            "mkdir -p /tmp/contracts && " +
            "cp -r /mnt/src /tmp/contracts/src && " +
            "cp -r /mnt/script /tmp/contracts/script && " +
            "cp -r /mnt/lib /tmp/contracts/dependencies && " +
            "cp /mnt/config/foundry.toml /tmp/contracts/foundry.toml && " +
            "cd /tmp/contracts && " +
            "forge script script/RegisterENS.s.sol:RegisterENS " +
            "--rpc-url {} --broadcast --non-interactive -vvv".format(rpc_url)
        ),
    )

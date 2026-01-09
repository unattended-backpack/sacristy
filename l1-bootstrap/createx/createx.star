# Bootstrap CreateX
#
# Uses a Foundry script to test the CreateX deterministic deployment factory.

# Minimum block number required before running CreateX tests.
# CreateX's _generateSalt() uses blockhash(block.number - 32), which underflows
# if block.number < 32.
MIN_BLOCK_NUMBER = 32

def bootstrap(plan, config, el_context):
    """
    Test the CreateX factory by deploying a contract via CREATE3.

    Uses a mined salt to deploy a Test20 contract to a vanity address,
    demonstrating CreateX's deterministic deployment capability.

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

    # Build the RPC URL.
    rpc_url = "http://{}:{}".format(
        el_context.service.ip_address,
        config["port_el_rpc_http"],
    )

    # Wait for at least MIN_BLOCK_NUMBER blocks before running CreateX tests.
    # This prevents underflow in CreateX's _generateSalt() function.
    plan.run_sh(
        name="wait-for-blocks",
        description="Waiting for block {} before testing CreateX".format(MIN_BLOCK_NUMBER),
        image=config["foundry_image"],
        run=(
            "echo 'Waiting for block {} before running CreateX test...' && ".format(MIN_BLOCK_NUMBER) +
            "while true; do " +
            "BLOCK=$(cast block-number --rpc-url {}); ".format(rpc_url) +
            "echo \"Current block: $BLOCK\"; " +
            "if [ \"$BLOCK\" -ge {} ]; then ".format(MIN_BLOCK_NUMBER) +
            "echo 'Block threshold reached, proceeding...'; break; " +
            "fi; " +
            "sleep {}; ".format(config["l1_seconds_per_slot"]) +
            "done"
        ),
    )

    # Run CreateX test via Foundry script.
    plan.run_sh(
        name="test-createx",
        description="Testing CreateX deterministic deployment factory",
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
            "forge script script/UseCreateX.s.sol:UseCreateX " +
            "--rpc-url {} --broadcast --non-interactive -vvv".format(rpc_url)
        ),
    )

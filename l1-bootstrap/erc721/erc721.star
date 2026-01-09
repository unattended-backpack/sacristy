# Bootstrap ERC-721
#
# Uses a Foundry script to mint test ERC-721 NFTs for each account.

def bootstrap(plan, config, el_context):
    """
    Mint test ERC-721 NFTs for all accounts using a Foundry script.

    Each account mints one NFT with custom text displayed as on-chain SVG art.

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

    # Run ERC-721 mint via Foundry script.
    rpc_url = "http://{}:{}".format(
        el_context.service.ip_address,
        config["port_el_rpc_http"],
    )
    plan.run_sh(
        name="mint-erc721",
        description="Minting test ERC-721 NFTs for {} accounts".format(
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
            "ACCOUNT_NAMES": ",".join([a["name"] for a in config["accounts"]]),
        },
        run=(
            "mkdir -p /tmp/contracts && " +
            "cp -r /mnt/src /tmp/contracts/src && " +
            "cp -r /mnt/script /tmp/contracts/script && " +
            "cp -r /mnt/lib /tmp/contracts/dependencies && " +
            "cp /mnt/config/foundry.toml /tmp/contracts/foundry.toml && " +
            "cd /tmp/contracts && " +
            "forge script script/MintERC721.s.sol:MintERC721 " +
            "--rpc-url {} --broadcast --non-interactive -vvv".format(rpc_url)
        ),
    )

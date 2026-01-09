# Bootstrap Contract Verification
#
# Submits genesis contract source code and bytecode to the eth-bytecode-db
# microservice for verification. This enables Blockscout to display verified
# source code for contracts deployed at genesis.

def bootstrap(plan, config):
    """
    Verify all genesis and bootstrap contracts with eth-bytecode-db.

    This submits bytecode → source mappings to the local eth-bytecode-db,
    allowing Blockscout to display verified source for initial contracts.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
    """

    # Get the eth-bytecode-db service.
    bytecode_db = plan.get_service("blockscout-eth-bytecode-db")
    bytecode_db_url = "http://{}:{}".format(
        bytecode_db.ip_address,
        config["port_blockscout_eth_bytecode_db"],
    )

    # Get compiled contract artifacts.
    out_artifact = plan.get_files_artifact("contracts-out")
    src_artifact = plan.get_files_artifact("contracts-src")
    foundry_artifact = plan.get_files_artifact("contracts-foundry-toml")
    lib_artifact = plan.get_files_artifact("contracts-lib")

    # Build the contracts list as JSON for the verification script.
    # Format: {"ContractName": "0xAddress", ...}
    contracts_json = json.encode(config["genesis_contracts"])

    # Upload the verification script.
    script_artifact = plan.render_templates(
        name="verify-script",
        config={
            "verify.sh": struct(
                template=read_file("./verify.sh"),
                data={},
            ),
        },
    )

    # Run verification for all genesis contracts.
    # Uses alpine with curl and jq for JSON processing and HTTP requests.
    plan.run_sh(
        name="verify-genesis-contracts",
        description="Verifying {} genesis contracts".format(
            len(config["genesis_contracts"]),
        ),
        image="dwdraju/alpine-curl-jq:latest",
        files={
            "/mnt/out": out_artifact,
            "/mnt/src": src_artifact,
            "/mnt/config": foundry_artifact,
            "/mnt/lib": lib_artifact,
            "/scripts": script_artifact,
        },
        env_vars={
            "BYTECODE_DB_URL": bytecode_db_url,
            "CONTRACTS_JSON": contracts_json,
        },
        run="sh /scripts/verify.sh",
    )

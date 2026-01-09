# Let there be light.
#
# Genesis generation for L1, using the `ethereum-genesis-generator` to deploy
# contracts and fund accounts.

def generate_genesis(plan, config, contracts_context):
    """
    Generate EL and CL genesis artifacts using `ethereum-genesis-generator`.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        contracts_context: Compiled contract artifacts.

    Returns a struct containing:
        - genesis: artifact with genesis.json, genesis.ssz, config.yaml.
        - jwt: artifact with jwtsecret.
    """

    # Derive prefunded accounts.
    premine_artifact = _derive_premine_json(plan, config)

    # Derive preloaded genesis contracts (from precompiled artifacts).
    contracts_artifact = _derive_contracts_json(
      plan,
      config,
      contracts_context,
    )

    # Create the genesis generator's `values.env` artifact from template.
    values_artifact = _render_values(plan, config)

    # Create EL and CL configuration artifacts. In the genesis generator these
    # are filled in by envsubst without templating.
    el_config_artifact = plan.upload_files(
        src="./el_config.yaml",
        name="el_config.yaml",
    )
    cl_config_artifact = plan.upload_files(
        src="./cl_config.yaml",
        name="cl_config.yaml",
    )
    cl_mnemonics_artifact = plan.upload_files(
        src="./mnemonics.yaml",
        name="mnemonics.yaml",
    )

    # Generate and return genesis results.
    # Note: Kurtosis artifacts are directories, so we mount them at /mnt and
    # copy files to their expected locations before running the generator.
    genesis_result = plan.run_sh(
        name="generate-genesis",
        description="Generating genesis files",
        image=config["genesis_generator_image"],
        env_vars={
            "ADDITIONAL_PRELOADED_CONTRACTS": "/preloaded/contracts.json",
        },
        files={
            "/mnt/values": values_artifact,
            "/mnt/el": el_config_artifact,
            "/mnt/cl": cl_config_artifact,
            "/mnt/mnemonics": cl_mnemonics_artifact,
            "/mnt/premine": premine_artifact,
            "/mnt/contracts": contracts_artifact,
        },
        store=[
            StoreSpec(src="/data/metadata/*", name="genesis-artifacts"),
            StoreSpec(src="/data/jwt/*", name="jwt-artifacts"),
        ],
        run=(
            "mkdir -p /config/el /config/cl /premine /preloaded && " +
            "cp /mnt/values/values.env /config/values.env && " +
            "cp /mnt/el/el_config.yaml /config/el/genesis-config.yaml && " +
            "cp /mnt/cl/cl_config.yaml /config/cl/config.yaml && " +
            "cp /mnt/mnemonics/mnemonics.yaml /config/cl/mnemonics.yaml && " +
            "cp /mnt/premine/* /premine/premine.json && " +
            "cp /mnt/contracts/* /preloaded/contracts.json && " +
            ". /config/values.env && " +
            "export EL_PREMINE_ADDRS=\"$(cat /premine/premine.json)\" && " +
            "export GENESIS_TIMESTAMP=$(date +%s) && " +
            "/work/entrypoint.sh all"
        ),
    )
    return struct(
        genesis=genesis_result.files_artifacts[0],
        jwt=genesis_result.files_artifacts[1],
    )


def _derive_premine_json(plan, config):
    """
    Derive prefunded account addresses and build the JSON input for genesis.

    Returns a file artifact containing the premine JSON information.
    The JSON format is: {"0xaddr1": "1000ETH", "0xaddr2": "2000ETH", ...}
    """
    mnemonic = config["mnemonic"]
    accounts = config.get("accounts", [])
    count = len(accounts)

    # Return an empty artifact if there are no accounts.
    if count == 0:
        return plan.render_templates(
            name="Deriving 0 premined addresses",
            config={
                "premine.json": struct(template="{}", data={}),
            },
        )

    # Otherwise, build a semicolon-separated balances string for the premine
    # derivation script to consume, and upload that script. Then build the
    # premine genesis result.
    balances = ";".join([acct["balance"] for acct in accounts])
    script_artifact = plan.upload_files(
        src="./derive_premine.sh",
        name="derive_premine.sh",
    )
    result = plan.run_sh(
        name="derive-premine",
        description="Deriving {} premined addresses".format(count),
        image=config["foundry_image"],
        files={
            "/scripts": script_artifact,
        },
        store=["/tmp/premine.json"],
        run="sh /scripts/derive_premine.sh '{}' '{}' '{}' > /tmp/premine.json".format(
            mnemonic, count, balances
        ),
    )
    return result.files_artifacts[0]


def _derive_contracts_json(plan, config, contracts_context):
    """
    Build preloaded contracts JSON from pre-compiled artifacts.

    Uses the compiled contract artifacts from contracts.build() and the
    deployment addresses from config to create the contracts.json file
    needed by the genesis generator.

    Returns a file artifact containing contracts.json.
    """
    genesis_contracts = config["genesis_contracts"]
    mapping_artifact = plan.render_templates(
        name="mapping",
        description="Rendering preloaded contracts mapping",
        config={
            "mapping.json": struct(
                template=json.encode(genesis_contracts),
                data={},
            ),
        },
    )

    # Derive the genesis file for preloaded contracts.
    script_artifact = plan.upload_files(
        src="./derive_contracts.sh",
        name="derive_contracts.sh",
    )
    result = plan.run_sh(
        name="derive-contracts",
        description="Building preloaded contracts JSON for genesis",
        image=config["foundry_image"],
        files={
            "/scripts": script_artifact,
            "/contracts": contracts_context.out,
            "/config": mapping_artifact,
        },
        store=["/tmp/contracts.json"],
        run=(
            "sh /scripts/derive_contracts.sh " +
            "/contracts /config/mapping.json > /tmp/contracts.json"
        ),
    )
    return result.files_artifacts[0]


def _render_values(plan, config):
    """
    Render the genesis generator's `values.env` from template.

    Note: EL_PREMINE_ADDRS is set dynamically from premine.json file at runtime.
    """
    accounts = config.get("accounts", [])
    validator_count = 0
    for acct in accounts:
        validator_count += acct.get("validators", 0)
    if validator_count == 0:
        fail("No validators configured; add 'validators' field to accounts.")

    # Render the actual template using configuration values.
    return plan.render_templates(
        name="genesis-values",
        description="Rendering genesis values.env template",
        config={
            "values.env": struct(
                template=read_file("./values.env.template"),
                data={
                    "chain_id": config["l1_chain_id"],
                    "seconds_per_slot": config["l1_seconds_per_slot"],
                    "slot_duration_ms": config["l1_seconds_per_slot"] * 1000,
                    "validator_count": validator_count,
                    "mnemonic": config["mnemonic"],
                },
            ),
        },
    )

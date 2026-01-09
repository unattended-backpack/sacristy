# Lodestar validator service
#
# Produces blocks for the testnet by staking with Lodestar.

def start(plan, config, genesis_artifacts, cl_context):
    """
    Start lodestar validator client with per-validator fee recipients.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        genesis_artifacts: Genesis artifacts (contains config.yaml).
        cl_context: Consensus layer context (beacon node connection).

    Returns:
        Service context for validators.
    """
    mnemonic = config["mnemonic"]
    
    # Calculate total validators and build assignments.
    accounts = config.get("accounts", [])
    assignments = _build_validator_assignments(accounts)
    total_validators = 0
    for a in assignments:
        total_validators += a["count"]
    if total_validators == 0:
        fail("No validators configured. Add 'validators' field to accounts.")

    # Generate proposer config with per-validator fee recipients.
    proposer_config_artifact = _generate_proposer_config(
        plan, config, mnemonic, accounts, assignments, total_validators
    )

    # Start the validator client.
    service = plan.add_service(
        name="lodestar-validator",
        config=ServiceConfig(
            image=config["l1_cl_image"],
            ports={
                "metrics": PortSpec(
                    number=config["port_validator_metrics"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/genesis": genesis_artifacts,
                "/config": proposer_config_artifact,
            },
            cmd=[
                "validator",
                "--preset=minimal",
                "--paramsFile=/genesis/config.yaml",
                "--dataDir=/data",
                "--beaconNodes={}".format(cl_context.http_url),
                "--fromMnemonic={}".format(mnemonic),
                "--mnemonicIndexes=0..{}".format(total_validators - 1),
                "--proposerSettingsFile=/config/proposer-config.yaml",
                "--metrics=true",
                "--metrics.address=0.0.0.0",
                "--metrics.port={}".format(config["port_validator_metrics"]),
                "--builder=false",
            ],
            min_cpu=500,
            min_memory=1024,
        ),
    )
    return struct(
        service=service,
        total_validators=total_validators,
        validator_assignments=assignments,
    )


def _build_validator_assignments(accounts):
    """
    Build list of validator assignments from accounts config.

    Returns list of {account_index, start_index, count} dicts.
    """
    assignments = []
    current_index = 0
    for i, account in enumerate(accounts):
        num_validators = account.get("validators", 0)
        if num_validators > 0:
            assignments.append({
                "account_index": i,
                "account_name": account["name"],
                "start_index": current_index,
                "count": num_validators,
            })
        current_index += num_validators
    return assignments


def _generate_proposer_config(
    plan, config, mnemonic, accounts, assignments, total_validators
):
    """
    Generate proposer settings file mapping validator pubkeys to fee recipients.

    This derives account addresses using Foundry and BLS pubkeys using ethdo,
    then builds the Lodestar proposer config JSON.
    """

    # Get account indices that have validators
    account_indices_with_validators = [a["account_index"] for a in assignments]
    if len(account_indices_with_validators) == 0:
        fail("No accounts with validators")
    max_account_index = max(account_indices_with_validators)

    # Derive account addresses.
    derive_script = plan.upload_files(
        src="./derive_addresses.sh",
        name="derive_addresses.sh",
    )
    addresses_result = plan.run_sh(
        name="derive-fee-recipient-addresses",
        description="Deriving {} addresses".format(max_account_index + 1),
        image=config["foundry_image"],
        files={
            "/scripts": derive_script,
        },
        store=[
            StoreSpec(src="/tmp/output/*", name="fee-recipient-addresses"),
        ],
        run=(
            "mkdir -p /tmp/output && " +
            "sh /scripts/derive_addresses.sh '{}' '{}' > ".format(
                mnemonic, max_account_index + 1
            ) +
            "/tmp/output/addresses.txt"
        ),
    )

    # Derive BLS pubkeys using ethdo.
    # Format: "account_index:start_index:count:account_name" for assignments.
    assignments_str = ";".join([
        "{}:{}:{}:{}".format(
          a["account_index"], a["start_index"], a["count"], a["account_name"]
        )
        for a in assignments
    ])
    proposer_script = plan.upload_files(
        src="./generate_proposer_config.sh",
        name="generate_proposer_config.sh",
    )
    result = plan.run_sh(
        name="generate-proposer-config",
        description="Generating proposer config for {} validators".format(
            total_validators
        ),
        image=config["ethdo_image"],
        files={
            "/scripts": proposer_script,
            "/addresses": addresses_result.files_artifacts[0],
        },
        store=[
            StoreSpec(src="/tmp/output/*", name="proposer-config"),
        ],
        run="sh /scripts/generate_proposer_config.sh '{}' '{}' '{}'".format(
            mnemonic, total_validators, assignments_str
        ),
    )
    return result.files_artifacts[0]

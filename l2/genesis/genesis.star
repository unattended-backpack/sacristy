# L2 Genesis
#
# Generates L2 genesis artifacts in two phases:
#   1. generate_base: JWT secret + genesis.json (before op-reth starts).
#   2. generate_rollup_config: rollup_config.json + l1_chain_config.json
#      (after op-reth starts, so we can query it for the real genesis hash).


def generate_base(plan, config):
    """
    Generate base genesis artifacts (phase 1, before op-reth).

    Returns a struct containing:
        - l2_genesis: artifact with genesis.json
        - jwt: artifact with jwtsecret
    """
    jwt = _generate_jwt(plan, config)
    l2_genesis = _build_genesis(plan, config)
    return struct(l2_genesis=l2_genesis, jwt=jwt)


def generate_rollup_config(plan, config, l2_el):
    """
    Generate rollup config artifacts (phase 2, after op-reth).

    Queries op-reth for the real L2 genesis hash and builds the rollup config.

    Returns a struct containing:
        - rollup_config: artifact with rollup_config.json
        - l1_chain_config: artifact with l1_chain_config.json
        - jwt: reference to the JWT artifact (for convenience)
    """
    rollup_config = _build_rollup_config(plan, config, l2_el)
    l1_chain_config = _build_l1_chain_config(plan, config)
    return struct(rollup_config=rollup_config, l1_chain_config=l1_chain_config)


def _generate_jwt(plan, config):
    """Generate a shared JWT secret for op-reth <-> kona-node."""
    result = plan.run_sh(
        name="generate-l2-jwt",
        description="Generating L2 JWT secret",
        image=config["foundry_image"],
        store=[
            StoreSpec(src="/tmp/jwt", name="l2-jwt"),
        ],
        run=(
            "mkdir -p /tmp/jwt && " +
            "openssl rand -hex 32 > /tmp/jwt/jwtsecret"
        ),
    )
    return result.files_artifacts[0]


def _build_genesis(plan, config):
    """Assemble genesis.json with predeploy alloc."""
    script_artifact = plan.upload_files(
        src="./build_genesis.sh",
        name="build-genesis-script",
    )
    result = plan.run_sh(
        name="build-l2-genesis",
        description="Assembling L2 genesis.json",
        image=config["foundry_image"],
        files={
            "/scripts": script_artifact,
        },
        store=[
            StoreSpec(src="/tmp/genesis", name="l2-genesis"),
        ],
        run=(
            "mkdir -p /tmp/genesis && " +
            "TIMESTAMP=$(date +%s) && " +
            # Use an empty alloc for now. The predeploys will be deployed
            # by the genesis forge script in a future iteration.
            "echo '{}' > /tmp/empty_alloc.json && " +
            "sh /scripts/build_genesis.sh /tmp/empty_alloc.json {} $TIMESTAMP > /tmp/genesis/genesis.json".format(
                config["l2_chain_id"],
            )
        ),
    )
    return result.files_artifacts[0]


def _build_rollup_config(plan, config, l2_el):
    """Build rollup_config.json by querying L1 and op-reth."""
    script_artifact = plan.upload_files(
        src="./build_rollup_config.sh",
        name="build-rollup-config-script",
    )

    batcher_key = config["l2_batcher_private_key"]

    result = plan.run_sh(
        name="build-rollup-config",
        description="Building L2 rollup config",
        image=config["foundry_image"],
        files={
            "/scripts": script_artifact,
        },
        store=[
            StoreSpec(src="/tmp/config", name="l2-rollup-config"),
        ],
        run=(
            "mkdir -p /tmp/config && " +
            # Query op-reth for the real L2 genesis hash.
            "L2_GENESIS_HASH=$(cast block 0 -f hash --rpc-url {}) && ".format(l2_el.rpc_http_url) +
            "BATCHER_ADDR=$(cast wallet address --private-key {}) && ".format(batcher_key) +
            "sh /scripts/build_rollup_config.sh " +
            "'{}' $L2_GENESIS_HASH {} {} '{}' '{}' '{}' $BATCHER_ADDR ".format(
                config["l1_rpc_url"],
                config["l1_chain_id"],
                config["l2_chain_id"],
                config["l2_system_config_address"],
                config["l2_optimism_portal_address"],
                config["l2_batch_inbox_address"],
            ) +
            "> /tmp/config/rollup_config.json"
        ),
    )
    return result.files_artifacts[0]


def _build_l1_chain_config(plan, config):
    """Build L1 chain config JSON."""
    script_artifact = plan.upload_files(
        src="./build_l1_chain_config.sh",
        name="build-l1-chain-config-script",
    )
    result = plan.run_sh(
        name="build-l1-chain-config",
        description="Building L1 chain config",
        image=config["foundry_image"],
        files={
            "/scripts": script_artifact,
        },
        store=[
            StoreSpec(src="/tmp/config", name="l2-l1-chain-config"),
        ],
        run=(
            "mkdir -p /tmp/config && " +
            "sh /scripts/build_l1_chain_config.sh '{}' {} > /tmp/config/l1_chain_config.json".format(
                config["l1_rpc_url"],
                config["l1_chain_id"],
            )
        ),
    )
    return result.files_artifacts[0]

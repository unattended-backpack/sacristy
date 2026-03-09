# Sacristy L2
#
# Deploys an OP Stack L2 rollup in its own Kurtosis enclave, consuming L1
# connection details from config. This allows running multiple L2 instances
# against a single shared L1, or against a public Ethereum testnet.
#
# Prerequisites:
#   1. L1 running (sacristy `make l1` or public testnet).
#   2. Sequencer and batcher accounts funded on L1.
#   3. L1 rollup contracts deployed via `make deploy-l2`.
#   4. Deployed addresses set in config.star, keys passed via CLI args.
#
# Usage:
#   make l2  # reads keys from .env
#   kurtosis run ./l2 --enclave sacristy-l2 \
#     '{"l2_sequencer_private_key": "0x...", "l2_batcher_private_key": "0x..."}'

config_module = import_module("../config.star")
genesis = import_module("./genesis/genesis.star")
op_reth = import_module("./op_reth/op_reth.star")
kona_node = import_module("./kona_node/kona_node.star")
kona_batcher = import_module("./kona_batcher/kona_batcher.star")
blockscout = import_module("./blockscout/blockscout.star")
traefik = import_module("./traefik/traefik.star")


def run(plan, args={}):
    """
    Deploy the L2 rollup.

    Args:
        plan: Kurtosis plan.
        args: Configuration overrides.

    Returns:
        All L2 service contexts.
    """

    # Load configuration with overrides.
    config = config_module.CONFIG | args

    # Validate required config.
    _validate(config)

    # Phase 1: Generate JWT + genesis.json (before op-reth).
    base = genesis.generate_base(plan, config)

    # Start L2 execution engine (op-reth). Must start first.
    l2_el = op_reth.start(plan, config, base.jwt, base.l2_genesis)

    # Phase 2: Build rollup config (queries op-reth for real genesis hash).
    rollup = genesis.generate_rollup_config(plan, config, l2_el)

    # Start rollup node (kona-node sequencer).
    l2_node = kona_node.start(plan, config, struct(
        rollup_config=rollup.rollup_config,
        l1_chain_config=rollup.l1_chain_config,
        jwt=base.jwt,
    ), l2_el)

    # Start batch submitter (kona-batcher) if enabled.
    l2_batcher = None
    if config.get("l2_batcher_enabled", True):
        l2_batcher = kona_batcher.start(plan, config, l2_el)

    # Start Blockscout block explorer if enabled.
    blockscout_context = None
    if config.get("l2_blockscout_enabled", True):
        blockscout_context = blockscout.start(plan, config, l2_el)

    # Start reverse proxy (traefik). Starts last.
    l2_traefik = traefik.start(plan, config, l2_el, blockscout_context=blockscout_context)

    return struct(
        config=config,
        l2_el=l2_el,
        l2_node=l2_node,
        l2_batcher=l2_batcher,
        l2_traefik=l2_traefik,
        blockscout=blockscout_context,
    )


def _validate(config):
    """Validate that required L2 configuration is present."""
    required = [
        "l1_rpc_url",
        "l1_beacon_url",
        "l2_sequencer_private_key",
    ]

    # Batcher key is only required when the batcher is enabled.
    if config.get("l2_batcher_enabled", True):
        required.append("l2_batcher_private_key")

    for key in required:
        value = config.get(key, "")
        if value == "" or value == None:
            fail("L2 config '{}' is required but not set.".format(key))

    # System config address must be deployed (not zero).
    if config.get("l2_system_config_address", "") == "0x0000000000000000000000000000000000000000":
        fail(
            "l2_system_config_address is zero. " +
            "Deploy L1 contracts first with `make deploy-l2` and update config.star."
        )

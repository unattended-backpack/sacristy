# Sacristy L2
#
# Deploys the Sigil L2 rollup in its own Kurtosis enclave, consuming L1
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
sigil = import_module("./sigil/sigil.star")
batcher = import_module("./batcher/batcher.star")
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

    # Genesis is a host-side artifact built once via `make genesis`.
    # The output root pinned into the deployed SigilVerifier is the
    # output root of THIS file, so building it inside the enclave on
    # every `make l2` would break the chain. Upload the existing file
    # as a kurtosis artifact; downstream services consume it as-is.
    genesis_artifact = plan.upload_files(
        src="../genesis.json",
        name="l2-genesis",
    )
    genesis_artifacts = struct(l2_genesis=genesis_artifact)

    # Start the unified Sigil node (EL + CL in one process).
    l2_sigil = sigil.start(plan, config, genesis_artifacts)

    # Start batch submitter if enabled.
    l2_batcher = None
    if config.get("l2_batcher_enabled", True):
        l2_batcher = batcher.start(plan, config, l2_sigil)

    # Start Blockscout block explorer if enabled.
    blockscout_context = None
    if config.get("l2_blockscout_enabled", True):
        blockscout_context = blockscout.start(plan, config, l2_sigil)

    # Start reverse proxy (traefik). Starts last.
    l2_traefik = traefik.start(plan, config, l2_sigil, blockscout_context=blockscout_context)

    return struct(
        config=config,
        l2_sigil=l2_sigil,
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

    # Verifier address must be deployed (not zero). Sigil's single L1
    # contract — see `config.star` for context — must exist before any
    # L2 service starts, since the deriver subscribes to its event
    # stream.
    if config.get("l2_verifier_address", "") == "0x0000000000000000000000000000000000000000":
        fail(
            "l2_verifier_address is zero. " +
            "Run `make genesis` then `make deploy-l2`, paste the printed " +
            "SigilVerifier address into config.star, then re-run `make l2`."
        )

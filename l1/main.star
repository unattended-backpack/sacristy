# Sacristy L1
#
# Deploys a minimal Ethereum L1 testnet with genesis accounts.
#
# Includes an optional observability stack:
# - Dora (CL),
# - Blobscan (blobs),
# - Blockscout (EL), with further optional extensions.
#
# Bootstrapping (ENS registration, blob seeding) is handled separately
# via `make bootstrap` using the bootstrap package.
#
# Usage:
#   kurtosis run ./l1 --enclave sacristy
#   kurtosis run ./l1 --enclave sacristy '{"l1_chain_id": 1}'

config_module = import_module("../config.star")
contracts = import_module("../contracts/contracts.star")
genesis = import_module("./genesis/genesis.star")
reth = import_module("./reth/reth.star")
lodestar = import_module("./lodestar/lodestar.star")
validator = import_module("./validator/validator.star")
dora = import_module("./dora/dora.star")
blockscout = import_module("./blockscout/blockscout.star")
blobscan = import_module("./blobscan/blobscan.star")
monitoring = import_module("./monitoring/monitoring.star")
traefik = import_module("./traefik/traefik.star")


def run(plan, args={}):
    """
    Deploy the L1 testnet.

    Args:
        plan: Kurtosis plan.
        args: Configuration overrides.

    Returns:
        All L1 service contexts.
    """

    # Load configuration with overrides.
    config = config_module.CONFIG | args

    # Build all contracts (compile once, use everywhere).
    contracts_context = contracts.build(plan, config)

    # Generate genesis artifacts.
    artifacts = genesis.generate_genesis(plan, config, contracts_context)

    # Start execution layer client (reth).
    el_context = reth.start(
        plan,
        config,
        artifacts.jwt,
        artifacts.genesis,
    )

    # Start consensus layer client (lodestar).
    cl_context = lodestar.start(
        plan,
        config,
        artifacts.jwt,
        artifacts.genesis,
        el_context,
    )

    # Start validators.
    validator_context = validator.start(
        plan,
        config,
        artifacts.genesis,
        cl_context,
    )

    # Optionally start the monitoring stack (Prometheus and Grafana).
    monitoring_context = None
    if config.get("monitoring_enabled", True):
        monitoring_context = monitoring.start(
            plan,
            config,
            el_context,
            cl_context,
            validator_context,
        )

    # Optionally start Dora, the CL explorer.
    dora_context = None
    if config.get("dora_enabled", True):
        dora_context = dora.start(
            plan,
            config,
            artifacts.genesis,
            cl_context,
        )

    # Optionally start Blobscan, the blob explorer.
    blobscan_context = None
    if config.get("blobscan_enabled", True):
        blobscan_context = blobscan.start(
            plan,
            config,
            el_context,
            cl_context,
        )

    # Optionally start Blockscout, the EL block explorer.
    blockscout_context = None
    if config.get("l1_blockscout_enabled", True):
        blockscout_context = blockscout.start(
            plan,
            config,
            el_context,
            contracts_context,
        )

    # Start Traefik reverse proxy
    traefik_context = traefik.start(
        plan,
        config,
        el_context,
        cl_context,
        dora_context=dora_context,
        blockscout_context=blockscout_context,
        blobscan_context=blobscan_context,
        monitoring_context=monitoring_context,
    )

    return struct(
        config=config,
        contracts=contracts_context,
        el=el_context,
        cl=cl_context,
        validator=validator_context,
        dora=dora_context,
        blockscout=blockscout_context,
        blobscan=blobscan_context,
        monitoring=monitoring_context,
        traefik=traefik_context,
        genesis=artifacts.genesis,
        jwt=artifacts.jwt,
    )

# Sacristy L2
#
# Deploys an OP Stack L2 rollup connected to the L1 testnet.
#
# Usage:
#   kurtosis run ./l2 --enclave sacristy
#   kurtosis run ./l2 --enclave sacristy '{"l2_chain_id": 901}'
#
# Note: Requires L1 to be running in the same enclave first.

config_module = import_module("../config.star")


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

    # TODO: Implement L2 deployment.
    plan.print("L2 deployment not yet implemented.")

    return struct(
        config=config,
    )

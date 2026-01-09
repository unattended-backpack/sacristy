# Sacristy is Ethereum testnet infrastructure for Sigil development.
#
# This is the root dispatcher that routes to -modules based on the target arg.
#
# Usage:
#   kurtosis run . --enclave sacristy
#   kurtosis run . --enclave sacristy '{"target": "l1"}'
#   kurtosis run . --enclave sacristy '{"target": "l1-bootstrap"}'
#   kurtosis run . --enclave sacristy '{"target": "l2"}'
#
# Or use the Makefile:
#   make l1            # Deploy L1
#   make l1-bootstrap  # Run L1 bootstrap
#   make l2            # Deploy L2

l1_module = import_module("./l1/main.star")
l1_bootstrap_module = import_module("./l1-bootstrap/main.star")
l2_module = import_module("./l2/main.star")


def run(plan, args={}):
    """
    Dispatch to the appropriate sub-module based on target.

    Args:
        plan: Kurtosis plan.
        args: Configuration with optional "target" key.
              Valid targets: "l1" (default), "l1-bootstrap", "l2"
    """
    target = args.get("target", "l1")
    if target == "l1":
        return l1_module.run(plan, args)
    elif target == "l1-bootstrap":
        return l1_bootstrap_module.run(plan, args)
    elif target == "l2":
        return l2_module.run(plan, args)
    else:
        fail("Unknown target: '{}'.".format(target))

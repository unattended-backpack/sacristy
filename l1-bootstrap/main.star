# L1 Bootstrap package for Sacristy testnet.
#
# This package runs bootstrapping scripts (ENS registration, blob seeding)
# against an existing Sacristy enclave. Use this for iterative development
# and debugging of bootstrap scripts.
#
# Usage:
#   make l1-bootstrap                 # Run against existing enclave.
#   kurtosis run ./l1-bootstrap --enclave sacristy

config_module = import_module("../config.star")
delegate = import_module("./delegate/delegate.star")
ens = import_module("./ens/ens.star")
weth = import_module("./weth/weth.star")
erc20 = import_module("./erc20/erc20.star")
erc721 = import_module("./erc721/erc721.star")
erc1155 = import_module("./erc1155/erc1155.star")
createx = import_module("./createx/createx.star")
blobs = import_module("./blobs/blobs.star")
verify = import_module("./verify/verify.star")


def run(plan, args={}):
    """
    Run bootstrapping scripts against an existing Sacristy enclave.

    This package expects the L1 infrastructure (reth, lodestar, etc.) to
    already be running in the enclave. It will:
    1. Set up EIP-7702 delegation for all accounts (always).
    2. Register ENS names for all accounts (if l1_bootstrap_ens_enabled).
    3. Deposit Ether into WETH for all accounts (if l1_bootstrap_weth_enabled).
    4. Mint test ERC-20 tokens (if l1_bootstrap_erc20_enabled).
    5. Mint test ERC-721 NFTs (if l1_bootstrap_erc721_enabled).
    6. Mint test ERC-1155 tokens (if l1_bootstrap_erc1155_enabled).
    7. Test CreateX deterministic deployment (if l1_bootstrap_createx_enabled).
    8. Seed blob transactions (if l1_bootstrap_blobs_enabled).
    9. Verify contracts (if l1_bootstrap_verify_enabled).

    Args:
        args: Configuration overrides (merged with CONFIG).
    """
    config = config_module.CONFIG | args

    # Get reference to the existing reth service.
    reth_service = plan.get_service("reth")
    el_context = struct(
        service=reth_service,
        rpc_http_url="http://{}:{}".format(
            reth_service.ip_address,
            config["port_el_rpc_http"],
        ),
        rpc_ws_url="ws://{}:{}".format(
            reth_service.ip_address,
            config["port_el_rpc_ws"],
        ),
        engine_url="http://{}:{}".format(
            reth_service.ip_address,
            config["port_el_engine"],
        ),
    )

    # Set up the EIP-7702 multicall delegation for all accounts.
    # This part is mandatory. Other scripts rely upon the multicall.
    delegate.bootstrap(plan, config, el_context)

    # Optionally run ENS registration.
    if config.get("l1_bootstrap_ens_enabled", False):
        ens.bootstrap(plan, config, el_context)

    # Optionally deposit Ether into WETH.
    if config.get("l1_bootstrap_weth_enabled", False):
        weth.bootstrap(plan, config, el_context)

    # Optionally mint test ERC-20 tokens.
    if config.get("l1_bootstrap_erc20_enabled", False):
        erc20.bootstrap(plan, config, el_context)

    # Optionally mint test ERC-721 NFTs.
    if config.get("l1_bootstrap_erc721_enabled", False):
        erc721.bootstrap(plan, config, el_context)

    # Optionally mint test ERC-1155 tokens.
    if config.get("l1_bootstrap_erc1155_enabled", False):
        erc1155.bootstrap(plan, config, el_context)

    # Optionally test the CreateX deterministic deployment factory.
    if config.get("l1_bootstrap_createx_enabled", False):
        createx.bootstrap(plan, config, el_context)

    # Optionally seed blob transactions.
    if config.get("l1_bootstrap_blobs_enabled", False):
        blobs.bootstrap(plan, config, el_context)

    # Optionally verify all contracts with eth-bytecode-db.
    if config.get("l1_bootstrap_verify_enabled", False):
        verify.bootstrap(plan, config)

    # All done.
    return struct()

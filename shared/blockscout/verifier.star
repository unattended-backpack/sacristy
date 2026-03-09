# Blockscout Smart Contract Verifier
#
# Verifies smart contract source code against deployed bytecode.


def start(plan, config):
    """
    Start the smart-contract-verifier microservice.

    Args:
        plan: Kurtosis plan.
        config: Configuration.

    Returns:
        Service context with verifier URL.
    """
    port = config["port_blockscout_verifier"]
    service = plan.add_service(
        name="blockscout-verifier",
        config=ServiceConfig(
            image=config["blockscout_verifier_image"],
            ports={
                "http": PortSpec(
                    number=port,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars={
                "SMART_CONTRACT_VERIFIER__SERVER__HTTP__ENABLED": "true",
                "SMART_CONTRACT_VERIFIER__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(
                    port,
                ),
                "SMART_CONTRACT_VERIFIER__SERVER__GRPC__ENABLED": "false",
                "SMART_CONTRACT_VERIFIER__SOLIDITY__ENABLED": "true",
                "SMART_CONTRACT_VERIFIER__SOLIDITY__COMPILERS_DIR": "/tmp/solidity-compilers",
                "SMART_CONTRACT_VERIFIER__SOLIDITY__REFRESH_VERSIONS_SCHEDULE": "0 0 * * * * *",
                "SMART_CONTRACT_VERIFIER__SOLIDITY__FETCHER__LIST__LIST_URL": "https://binaries.soliditylang.org/linux-amd64/list.json",
                "SMART_CONTRACT_VERIFIER__VYPER__ENABLED": "true",
                "SMART_CONTRACT_VERIFIER__VYPER__COMPILERS_DIR": "/tmp/vyper-compilers",
                "SMART_CONTRACT_VERIFIER__VYPER__REFRESH_VERSIONS_SCHEDULE": "0 0 * * * * *",
                "SMART_CONTRACT_VERIFIER__VYPER__FETCHER__LIST__LIST_URL": "https://raw.githubusercontent.com/blockscout/solc-bin/main/vyper.list.json",
                "SMART_CONTRACT_VERIFIER__ZKSYNC_SOLIDITY__ENABLED": "false",
                "SMART_CONTRACT_VERIFIER__SOURCIFY__ENABLED": "true",
                "SMART_CONTRACT_VERIFIER__SOURCIFY__API_URL": "https://sourcify.dev/server/",
                "SMART_CONTRACT_VERIFIER__SOURCIFY__VERIFICATION_ATTEMPTS": "3",
                "SMART_CONTRACT_VERIFIER__SOURCIFY__REQUEST_TIMEOUT": "15",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    return struct(
        service=service,
        url="http://{}:{}".format(service.ip_address, port),
    )

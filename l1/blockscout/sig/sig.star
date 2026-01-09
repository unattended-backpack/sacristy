# Blockscout Signature Provider
#
# Resolves function and event signatures from various sources.


def start(plan, config, bytecode=None):
    """
    Start the sig-provider microservice.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        bytecode: Optional bytecode database context.

    Returns:
        Service context with signature provider URL.
    """
    port = config["port_blockscout_sig_provider"]
    env_vars = {
        "SIG_PROVIDER__SERVER__HTTP__ENABLED": "true",
        "SIG_PROVIDER__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(port),
        "SIG_PROVIDER__SERVER__GRPC__ENABLED": "false",
        "SIG_PROVIDER__SOURCES__FOURBYTE": "https://www.4byte.directory/",
        "SIG_PROVIDER__SOURCES__SIGETH": "https://api.4byte.sourcify.dev/",
    }

    # Use local eth-bytecode-db if available.
    if bytecode:
        env_vars["SIG_PROVIDER__SOURCES__ETH_BYTECODE_DB__ENABLED"] = "true"
        env_vars["SIG_PROVIDER__SOURCES__ETH_BYTECODE_DB__URL"] = bytecode.url

    # Start and return the service.
    service = plan.add_service(
        name="blockscout-sig-provider",
        config=ServiceConfig(
            image=config["blockscout_sig_provider_image"],
            ports={
                "http": PortSpec(
                    number=port,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars=env_vars,
            min_cpu=100,
            min_memory=256,
        ),
    )
    return struct(
        service=service,
        url="http://{}:{}".format(service.ip_address, port),
    )

# Blockscout Bytecode Database
#
# Stores and indexes verified contract bytecode for reuse across chains.


def start(plan, config, postgres, verifier):
    """
    Start the eth-bytecode-db microservice.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        postgres: PostgreSQL context (for database connection).
        verifier: Verifier context (for verification requests).

    Returns:
        Service context with bytecode database URL.
    """
    port = config["port_blockscout_eth_bytecode_db"]

    # Create a separate database for eth-bytecode-db.
    plan.exec(
        service_name="blockscout-db",
        recipe=ExecRecipe(
            command=[
                "sh", "-c",
                "psql -U blockscout -c 'CREATE DATABASE eth_bytecode_db;' || true",
            ],
        ),
    )
    service = plan.add_service(
        name="blockscout-eth-bytecode-db",
        config=ServiceConfig(
            image=config["blockscout_eth_bytecode_db_image"],
            ports={
                "http": PortSpec(
                    number=port,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars={
                "ETH_BYTECODE_DB__SERVER__HTTP__ENABLED": "true",
                "ETH_BYTECODE_DB__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(port),
                "ETH_BYTECODE_DB__SERVER__GRPC__ENABLED": "false",
                "ETH_BYTECODE_DB__DATABASE__URL": "postgresql://blockscout:blockscout@{}:{}/eth_bytecode_db".format(
                    postgres.service.ip_address, config["port_postgres"],
                ),
                "ETH_BYTECODE_DB__DATABASE__CREATE_DATABASE": "true",
                "ETH_BYTECODE_DB__DATABASE__RUN_MIGRATIONS": "true",
                "ETH_BYTECODE_DB__VERIFIER__HTTP_URL": verifier.url,
                "ETH_BYTECODE_DB__SOURCIFY__BASE_URL": "https://sourcify.dev/server/",
                "ETH_BYTECODE_DB__VERIFIER_ALLIANCE_DATABASE__ENABLED": "false",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    return struct(
        service=service,
        url="http://{}:{}".format(service.ip_address, port),
    )

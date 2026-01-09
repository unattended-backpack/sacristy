# Blockscout Statistics
#
# Aggregates and serves chain statistics and charts.


def start(plan, config, postgres, backend):
    """
    Start the stats microservice.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        postgres: PostgreSQL context (for database connection).
        backend: Blockscout backend service (for API connection).

    Returns:
        Service context with stats URL.
    """
    port = config["port_blockscout_stats"]

    # Create a separate database for stats.
    plan.exec(
        service_name="blockscout-db",
        recipe=ExecRecipe(
            command=[
                "sh", "-c",
                "psql -U blockscout -c 'CREATE DATABASE blockscout_stats;' || true",
            ],
        ),
    )
    service = plan.add_service(
        name="blockscout-stats",
        config=ServiceConfig(
            image=config["blockscout_stats_image"],
            ports={
                "http": PortSpec(
                    number=port,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars={
                "STATS__SERVER__HTTP__ENABLED": "true",
                "STATS__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(port),
                "STATS__SERVER__GRPC__ENABLED": "false",
                "STATS__DB_URL": "postgresql://blockscout:blockscout@{}:{}/blockscout_stats".format(
                    postgres.service.ip_address, config["port_postgres"],
                ),
                "STATS__BLOCKSCOUT_DB_URL": postgres.url,
                "STATS__CREATE_DATABASE": "true",
                "STATS__RUN_MIGRATIONS": "true",
                "STATS__BLOCKSCOUT_API_URL": "http://{}:{}".format(
                    backend.ip_address, config["port_blockscout_http"],
                ),
                "STATS__DEFAULT_SCHEDULE": "0 * * * * * *",
                "STATS__FORCE_UPDATE_ON_START": "true",
                "STATS__DISABLE_INTERNAL_TRANSACTIONS": "true",
                "STATS__CONDITIONAL_START__INTERNAL_TRANSACTIONS_RATIO__ENABLED": "false",
                "STATS__CONDITIONAL_START__BLOCKS_RATIO__THRESHOLD": "0.5",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    return struct(
        service=service,
        url="http://{}:{}".format(service.ip_address, port),
    )

# Blobscan
#
# The Ethereum blob transaction explorer.

def start(plan, config, el_context, cl_context):
    """
    Start the Blobscan blob explorer with all required services.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: Execution layer context (RPC connection).
        cl_context: Consensus layer context (beacon API).

    Returns:
        Service context with Blobscan UI URL.
    """
    postgres = _start_postgres(plan, config)
    redis = _start_redis(plan, config)
    api = _start_api(plan, config, el_context, cl_context, postgres, redis)
    indexer = _start_indexer(plan, config, el_context, cl_context, api)
    web = _start_web(plan, config, api, postgres, redis)
    return struct(
        postgres=postgres,
        redis=redis,
        api=api,
        indexer=indexer,
        web=web,
        http_url="http://{}:{}".format(
            web.ip_address,
            config["port_blobscan_web"],
        ),
    )


def _start_postgres(plan, config):
    """Start PostgreSQL for Blobscan."""
    port = config["port_postgres"]
    service = plan.add_service(
        name="blobscan-db",
        config=ServiceConfig(
            image=config["postgres_image"],
            ports={
                "postgres": PortSpec(
                    number=port,
                    transport_protocol="TCP",
                ),
            },
            env_vars={
                "POSTGRES_USER": "blobscan",
                "POSTGRES_PASSWORD": "blobscan",
                "POSTGRES_DB": "blobscan",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    plan.exec(
        service_name="blobscan-db",
        recipe=ExecRecipe(
            command=[
                "sh", "-c", "until pg_isready -U blobscan; do sleep 1; done"
            ],
        ),
    )
    return struct(
        service=service,
        url="postgresql://blobscan:blobscan@{}:{}/blobscan".format(
            service.ip_address, port,
        ),
    )


def _start_redis(plan, config):
    """Start Redis for Blobscan caching."""
    port = config["port_redis"]
    service = plan.add_service(
        name="blobscan-redis",
        config=ServiceConfig(
            image=config["redis_image"],
            ports={
                "redis": PortSpec(
                    number=port,
                    transport_protocol="TCP",
                ),
            },
            min_cpu=100,
            min_memory=256,
        ),
    )
    return struct(
        service=service,
        url="redis://{}:{}".format(service.ip_address, port),
    )


def _start_api(plan, config, el_context, cl_context, postgres, redis):
    """Start Blobscan API server."""
    service = plan.add_service(
        name="blobscan-api",
        config=ServiceConfig(
            image=config["blobscan_api_image"],
            ports={
                "http": PortSpec(
                    number=config["port_blobscan_api"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars={
                "DATABASE_URL": postgres.url,
                "DIRECT_URL": postgres.url,
                "REDIS_URI": redis.url,
                "CHAIN_ID": "1",
                "NETWORK_NAME": "devnet",
                "BLOBSCAN_API_PORT": str(config["port_blobscan_api"]),
                "BLOBSCAN_API_BASE_URL": "http://blobscan-api.sacristy.local",
                "NODE_ENV": "production",
                "SECRET_KEY": "sigil-testnet-blobscan-secret-key-that-is-at-least-32-characters-long",
                "BLOB_DATA_API_KEY": "sigil-testnet-blob-data-api-key",
                "POSTGRES_STORAGE_ENABLED": "true",
                "GOOGLE_STORAGE_ENABLED": "false",
                "SWARM_STORAGE_ENABLED": "false",
                "DENCUN_FORK_SLOT": "0",
                "STATS_SYNCER_OVERALL_CRON_PATTERN": "* * * * *",
                "STATS_SYNCER_DAILY_CRON_PATTERN": "*/5 * * * *",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    return struct(
        service=service,
        url="http://{}:{}".format(
            service.ip_address,
            config["port_blobscan_api"],
        ),
    )


def _start_indexer(plan, config, el_context, cl_context, api):
    """Start Blobscan indexer."""
    service = plan.add_service(
        name="blobscan-indexer",
        config=ServiceConfig(
            image=config["blobscan_indexer_image"],
            env_vars={
                "BLOBSCAN_API_ENDPOINT": api.url,
                "SECRET_KEY": "sigil-testnet-blobscan-secret-key-that-is-at-least-32-characters-long",
                "EXECUTION_NODE_ENDPOINT": el_context.rpc_http_url,
                "BEACON_NODE_ENDPOINT": cl_context.http_url,
                "CHAIN_ID": "1",
                "NETWORK_NAME": "devnet",
                "DENCUN_FORK_SLOT": "0",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    return service


def _start_web(plan, config, api, postgres, redis):
    """Start Blobscan web frontend."""
    service = plan.add_service(
        name="blobscan-web",
        config=ServiceConfig(
            image=config["blobscan_web_image"],
            ports={
                "http": PortSpec(
                    number=config["port_blobscan_web"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars={
                "DATABASE_URL": postgres.url,
                "DIRECT_URL": postgres.url,
                "REDIS_URI": redis.url,
                "NEXT_PUBLIC_BLOBSCAN_API_URL": api.url,
                "BLOBSCAN_API_URL": api.url,
                "BLOBSCAN_API_BASE_URL": "http://blobscan-api:{}".format(config["port_blobscan_api"]),
                "CHAIN_ID": "1",
                "NEXT_PUBLIC_CHAIN_ID": "1",
                "NEXT_PUBLIC_NETWORK_NAME": "mainnet",
                "PUBLIC_NETWORK_NAME": "mainnet",
                "PORT": str(config["port_blobscan_web"]),
                "NODE_ENV": "production",
                "NEXTAUTH_URL": "http://localhost:{}".format(config["port_blobscan_web"]),
                "SECRET_KEY": "sigil-testnet-blobscan-secret-key-that-is-at-least-32-characters-long",
                "BLOB_DATA_API_KEY": "sigil-testnet-blob-data-api-key",
                "NEXT_PUBLIC_VERCEL_ANALYTICS_ENABLED": "false",
                "NEXT_PUBLIC_MATOMO_URL": "",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    return service

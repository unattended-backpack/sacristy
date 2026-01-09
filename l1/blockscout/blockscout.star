# Blockscout
#
# Blockscout is an Ethereum execution layer block explorer.

backend_config = import_module("./backend.star")
frontend_config = import_module("./frontend.star")
bens = import_module("./bens/bens.star")
verifier = import_module("./verifier/verifier.star")
bytecode = import_module("./bytecode/bytecode.star")
sig = import_module("./sig/sig.star")
stats = import_module("./stats/stats.star")


def start(plan, config, el_context, contracts_context):
    """
    Start the Blockscout block explorer with optional services.

    Includes PostgreSQL and optional services like BENS (ENS indexing), a
    contract verifier, bytecode database, signature provider, and statistics.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: Execution layer context (RPC connection).
        contracts_context: Compiled contract artifacts from contracts.build().

    Returns:
        Service context with Blockscout UI URL.
    """
    postgres = _start_postgres(plan, config)

    # Read feature flags.
    verifier_enabled = config.get("l1_blockscout_verifier_enabled", True)
    bytecode_enabled = config.get("l1_blockscout_bytecode_enabled", True)
    sig_enabled = config.get("l1_blockscout_sig_enabled", True)
    bens_enabled = config.get("l1_blockscout_ens_enabled", True)
    stats_enabled = config.get("l1_blockscout_stats_enabled", True)

    # Start optional microservices (order matters due to dependencies).
    # 1. Start smart-contract-verifier (no dependencies).
    verifier_context = None
    if verifier_enabled:
        verifier_context = verifier.start(plan, config)

    # 2. Start eth-bytecode-db (depends on verifier).
    bytecode_context = None
    if verifier_enabled and bytecode_enabled:
        bytecode_context = bytecode.start(
            plan, config, postgres, verifier_context
        )

    # 3. Start sig-provider (can use eth-bytecode-db, but works without it).
    sig_context = None
    if sig_enabled:
        sig_context = sig.start(plan, config, bytecode_context)

    # 4. Start BENS (ENS indexing).
    bens_context = None
    if bens_enabled:
        bens_context = bens.start(plan, config, el_context, contracts_context)

    # Get ENS config.
    ens_registry_address = config["genesis_contracts"]["ENSRegistry"]
    bens_url = bens_context.url if bens_context else None

    # Start Blockscout backend (API) with microservices configured.
    backend = _start_backend(
        plan,
        config,
        el_context,
        postgres,
        bytecode_context,
        sig_context,
        ens_registry_address,
        bens_url,
    )

    # 4. Start stats (depends on blockscout backend being ready).
    stats_context = None
    if stats_enabled:
        stats_context = stats.start(plan, config, postgres, backend)

    # Start Blockscout frontend with stats API and BENS integration.
    frontend = _start_frontend(plan, config, backend, stats_context, bens_url)
    return struct(
        postgres=postgres,
        bens=bens_context,
        verifier=verifier_context,
        bytecode=bytecode_context,
        sig=sig_context,
        stats=stats_context,
        backend=backend,
        frontend=frontend,
        http_url="http://{}:{}".format(
            frontend.ip_address,
            config["port_blockscout_frontend"],
        ),
    )


def _start_postgres(plan, config):
    """Start PostgreSQL for Blockscout."""
    port = config["port_postgres"]
    service = plan.add_service(
        name="blockscout-db",
        config=ServiceConfig(
            image=config["postgres_image"],
            ports={
                "postgres": PortSpec(
                    number=port,
                    transport_protocol="TCP",
                ),
            },
            env_vars={
                "POSTGRES_USER": "blockscout",
                "POSTGRES_PASSWORD": "blockscout",
                "POSTGRES_DB": "blockscout",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    plan.exec(
        service_name="blockscout-db",
        recipe=ExecRecipe(
            command=["sh", "-c", "until pg_isready -U blockscout; do sleep 1; done"],
        ),
    )
    return struct(
        service=service,
        url="postgresql://blockscout:blockscout@{}:{}/blockscout".format(
            service.ip_address, port,
        ),
    )


def _start_backend(
    plan,
    config,
    el_context,
    postgres,
    bytecode_context,
    sig_context,
    ens_registry_address,
    bens_url,
):
    """Start Blockscout backend with microservices integration."""
    env_vars = dict(backend_config.CONFIG)

    # Add dynamic values computed at runtime.
    env_vars["DATABASE_URL"] = postgres.url
    env_vars["ETHEREUM_JSONRPC_HTTP_URL"] = el_context.rpc_http_url
    env_vars["ETHEREUM_JSONRPC_TRACE_URL"] = el_context.rpc_http_url
    env_vars["ETHEREUM_JSONRPC_WS_URL"] = el_context.rpc_ws_url
    env_vars["CHAIN_ID"] = str(config["l1_chain_id"])
    env_vars["PORT"] = str(config["port_blockscout_http"])

    # Add ENS configuration if registry address provided.
    if ens_registry_address:
        env_vars["ENS_ENABLED"] = "true"
        env_vars["ENS_REGISTRY_CONTRACT"] = ens_registry_address

    # Add BENS microservice configuration if URL provided.
    if bens_url:
        env_vars["MICROSERVICE_BENS_ENABLED"] = "true"
        env_vars["MICROSERVICE_BENS_URL"] = bens_url

    # Add smart contract verifier via eth-bytecode-db if enabled.
    if bytecode_context:
        env_vars["MICROSERVICE_SC_VERIFIER_ENABLED"] = "true"
        env_vars["MICROSERVICE_SC_VERIFIER_URL"] = bytecode_context.url
        env_vars["MICROSERVICE_SC_VERIFIER_TYPE"] = "eth_bytecode_db"
        env_vars["MICROSERVICE_ETH_BYTECODE_DB_ENABLED"] = "true"
        env_vars["MICROSERVICE_ETH_BYTECODE_DB_URL"] = bytecode_context.url

    # Add signature provider if enabled.
    if sig_context:
        env_vars["MICROSERVICE_SIG_PROVIDER_ENABLED"] = "true"
        env_vars["MICROSERVICE_SIG_PROVIDER_URL"] = sig_context.url

    # Start the service.
    service = plan.add_service(
        name="blockscout",
        config=ServiceConfig(
            image=config["blockscout_image"],
            ports={
                "http": PortSpec(
                    number=config["port_blockscout_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars=env_vars,
            cmd=[
                "sh", "-c",
                "bin/blockscout eval 'Elixir.Explorer.ReleaseTasks.create_and_migrate()' && bin/blockscout start",
            ],
            min_cpu=500,
            min_memory=1024,
        ),
    )
    return service


def _start_frontend(plan, config, backend, stats_context, bens_url):
    """Start Blockscout frontend with optional stats API and BENS integration."""
    env_vars = dict(frontend_config.CONFIG)

    # Add dynamic values computed at runtime.
    env_vars["NEXT_PUBLIC_API_HOST"] = backend.ip_address
    env_vars["NEXT_PUBLIC_API_PORT"] = str(config["port_blockscout_http"])
    env_vars["NEXT_PUBLIC_NETWORK_ID"] = str(config["l1_chain_id"])
    env_vars["PORT"] = str(config["port_blockscout_frontend"])

    # Stats API - enables charts and statistics.
    if stats_context:
        env_vars["NEXT_PUBLIC_STATS_API_HOST"] = "http://{}:{}".format(
            stats_context.service.ip_address,
            config["port_blockscout_stats"],
        )

    # Add BENS (Name Service) configuration if URL provided.
    if bens_url:
        env_vars["NEXT_PUBLIC_NAME_SERVICE_API_HOST"] = bens_url

    # Start the service.
    service = plan.add_service(
        name="blockscout-frontend",
        config=ServiceConfig(
            image=config["blockscout_frontend_image"],
            ports={
                "http": PortSpec(
                    number=config["port_blockscout_frontend"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars=env_vars,
            min_cpu=250,
            min_memory=512,
        ),
    )
    return service

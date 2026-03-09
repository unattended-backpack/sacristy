# L2 Blockscout
#
# Blockscout block explorer for the L2 rollup. Uses the same microservice
# images as L1 but reads l2_blockscout_* config flags and l2_chain_id.
# Since L2 runs in a separate Kurtosis enclave, service names are identical
# to L1 (blockscout-db, blockscout, blockscout-frontend) without conflict.

backend_config = import_module("./backend.star")
frontend_config = import_module("./frontend.star")
verifier = import_module("../../shared/blockscout/verifier.star")
bytecode = import_module("../../shared/blockscout/bytecode.star")
sig = import_module("../../shared/blockscout/sig.star")
stats = import_module("../../shared/blockscout/stats.star")


def start(plan, config, el_context):
    """
    Start the L2 Blockscout block explorer with optional services.

    Includes PostgreSQL and optional services like a contract verifier,
    bytecode database, signature provider, and statistics.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: L2 execution layer context (RPC connection).

    Returns:
        Service context with Blockscout UI URL.
    """
    postgres = _start_postgres(plan, config)

    # Read feature flags.
    verifier_enabled = config.get("l2_blockscout_verifier_enabled", True)
    bytecode_enabled = config.get("l2_blockscout_bytecode_enabled", True)
    sig_enabled = config.get("l2_blockscout_sig_enabled", True)
    stats_enabled = config.get("l2_blockscout_stats_enabled", False)

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

    # Start Blockscout backend (API) with microservices configured.
    backend = _start_backend(
        plan,
        config,
        el_context,
        postgres,
        bytecode_context,
        sig_context,
    )

    # 4. Start stats (depends on blockscout backend being ready).
    stats_context = None
    if stats_enabled:
        stats_context = stats.start(plan, config, postgres, backend)

    # Start Blockscout frontend with optional stats API.
    frontend = _start_frontend(plan, config, backend, stats_context)
    return struct(
        postgres=postgres,
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
):
    """Start Blockscout backend with microservices integration."""
    env_vars = dict(backend_config.CONFIG)

    # Add dynamic values computed at runtime.
    env_vars["DATABASE_URL"] = postgres.url
    env_vars["ETHEREUM_JSONRPC_HTTP_URL"] = el_context.rpc_http_url
    env_vars["ETHEREUM_JSONRPC_TRACE_URL"] = el_context.rpc_http_url
    env_vars["ETHEREUM_JSONRPC_WS_URL"] = el_context.rpc_ws_url
    env_vars["CHAIN_ID"] = str(config["l2_chain_id"])
    env_vars["PORT"] = str(config["port_blockscout_http"])

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


def _start_frontend(plan, config, backend, stats_context):
    """Start Blockscout frontend with optional stats API."""
    env_vars = dict(frontend_config.CONFIG)

    # Add dynamic values computed at runtime.
    env_vars["NEXT_PUBLIC_API_HOST"] = backend.ip_address
    env_vars["NEXT_PUBLIC_API_PORT"] = str(config["port_blockscout_http"])
    env_vars["NEXT_PUBLIC_NETWORK_ID"] = str(config["l2_chain_id"])
    env_vars["PORT"] = str(config["port_blockscout_frontend"])

    # Stats API - enables charts and statistics.
    if stats_context:
        env_vars["NEXT_PUBLIC_STATS_API_HOST"] = "http://{}:{}".format(
            stats_context.service.ip_address,
            config["port_blockscout_stats"],
        )

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

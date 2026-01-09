# BENS (Blockscout ENS)
#
# ENS indexing for Blockscout.
# Requires: IPFS, graph-node, ENS subgraph, BENS service


def start(plan, config, el_context, contracts_context):
    """
    Start the BENS infrastructure for ENS indexing.

    This includes:
    - IPFS node (for subgraph storage).
    - Dedicated PostgreSQL for graph-node (requires C locale).
    - graph-node (The Graph Protocol indexer).
    - ENS subgraph deployment.
    - BENS microservice (reads from graph-node's PostgreSQL).

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: Execution layer context (RPC endpoint).
        contracts_context: Compiled contract artifacts from contracts.build().

    Returns:
        Struct with BENS service URL.
    """
    ipfs = _start_ipfs(plan, config)
    graph_postgres = _start_graph_postgres(plan, config)
    graph_node = _start_graph_node(plan, config, el_context, ipfs, graph_postgres)

    # Deploy ENS subgraph
    _deploy_ens_subgraph(plan, config, graph_node, ipfs, el_context, contracts_context)

    # Start BENS (connects to graph-node's PostgreSQL for subgraph data)
    bens = _start_bens(plan, config, graph_node, graph_postgres)
    return struct(
        ipfs=ipfs,
        graph_postgres=graph_postgres,
        graph_node=graph_node,
        bens=bens,
        url="http://{}:{}".format(bens.service.ip_address, config["port_bens_http"]),
    )


def _start_ipfs(plan, config):
    """Start IPFS node for subgraph storage."""
    service = plan.add_service(
        name="ipfs",
        config=ServiceConfig(
            image=config["ipfs_image"],
            ports={
                "api": PortSpec(
                    number=config["port_ipfs_api"],
                    transport_protocol="TCP",
                ),
                "gateway": PortSpec(
                    number=config["port_ipfs_gateway"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            env_vars={
                "IPFS_PROFILE": "server",
            },
            min_cpu=100,
            min_memory=256,
        ),
    )
    plan.exec(
        service_name="ipfs",
        recipe=ExecRecipe(
            command=["sh", "-c", "until ipfs id 2>/dev/null; do sleep 1; done"],
        ),
    )
    return struct(
        service=service,
        api_url="http://{}:{}".format(service.ip_address, config["port_ipfs_api"]),
    )


def _start_graph_postgres(plan, config):
    """
    Start dedicated PostgreSQL for graph-node with C locale.

    Graph-node requires PostgreSQL with C locale for proper indexing.
    We use a separate instance to avoid affecting Blockscout's database.
    """
    port = config["port_postgres"]
    service = plan.add_service(
        name="graph-postgres",
        config=ServiceConfig(
            image=config["postgres_image"],
            ports={
                "postgres": PortSpec(
                    number=port,
                    transport_protocol="TCP",
                ),
            },
            env_vars={
                "POSTGRES_USER": "graph",
                "POSTGRES_PASSWORD": "graph",
                "POSTGRES_DB": "graph_node",
                "POSTGRES_INITDB_ARGS": "--encoding=UTF-8 --locale=C",
            },
            min_cpu=100,
            min_memory=256,
        ),
    )
    plan.exec(
        service_name="graph-postgres",
        recipe=ExecRecipe(
            command=["sh", "-c", "until pg_isready -U graph; do sleep 1; done"],
        ),
    )
    return struct(
        service=service,
        port=port,
    )


def _start_graph_node(plan, config, el_context, ipfs, graph_postgres):
    """Start The Graph Protocol graph-node."""
    service = plan.add_service(
        name="graph-node",
        config=ServiceConfig(
            image=config["graph_node_image"],
            ports={
                "http": PortSpec(
                    number=config["port_graph_node_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "admin": PortSpec(
                    number=config["port_graph_node_admin"],
                    transport_protocol="TCP",
                ),
                "index": PortSpec(
                    number=config["port_graph_node_index"],
                    transport_protocol="TCP",
                ),
            },
            env_vars={
                "postgres_host": graph_postgres.service.ip_address,
                "postgres_port": str(graph_postgres.port),
                "postgres_user": "graph",
                "postgres_pass": "graph",
                "postgres_db": "graph_node",
                "ipfs": "{}:{}".format(ipfs.service.ip_address, config["port_ipfs_api"]),
                "ethereum": "sacristy:{}".format(el_context.rpc_http_url),
                "GRAPH_LOG": "info",
                "GRAPH_ETHEREUM_CLEANUP_BLOCKS": "true",
                "EXPERIMENTAL_SUBGRAPH_VERSION_SWITCHING_MODE": "synced",
            },
            min_cpu=500,
            min_memory=1024,
        ),
    )
    plan.exec(
        service_name="graph-node",
        recipe=ExecRecipe(
            command=["sh", "-c", "sleep 10"],
        ),
    )
    return struct(
        service=service,
        http_url="http://{}:{}".format(service.ip_address, config["port_graph_node_http"]),
        admin_url="http://{}:{}".format(service.ip_address, config["port_graph_node_admin"]),
    )


def _deploy_ens_subgraph(plan, config, graph_node, ipfs, el_context, contracts_context):
    """
    Deploy a minimal ENS subgraph to graph-node.

    This creates a custom subgraph that matches our simplified ENS contracts.
    ABIs are extracted from the pre-compiled contract artifacts.
    """

    # Load subgraph files from the subgraph directory. Only subgraph.yaml needs
    # templating; contract ABIs are extracted from contracts_context.out.
    subgraph_artifact = plan.render_templates(
        name="ens-subgraph",
        config={
            "schema.graphql": struct(
                template=read_file("./subgraph/schema.graphql"),
                data={},
            ),
            "subgraph.yaml": struct(
                template=read_file("./subgraph/subgraph.yaml.template"),
                data={
                    "network": "sacristy",
                    "registry_address": config["genesis_contracts"]["ENSRegistry"],
                    "resolver_address": config["genesis_contracts"]["PublicResolver"],
                    "start_block": "0",
                },
            ),
            "src/mapping.ts": struct(
                template=read_file("./subgraph/src/mapping.ts"),
                data={},
            ),
            "package.json": struct(
                template=read_file("./subgraph/package.json"),
                data={},
            ),
        },
    )

    # Build and deploy subgraph using graph-cli.
    deploy_script = plan.upload_files(
        src="./deploy_subgraph.sh",
        name="deploy-subgraph-script",
    )
    plan.run_sh(
        name="deploy-ens-subgraph",
        description="Building and deploying ENS subgraph",
        image=config["node_image"],
        files={
            "/subgraph": subgraph_artifact,
            "/contracts": contracts_context.out,
            "/scripts": deploy_script,
        },
        env_vars={
            "GRAPH_NODE_ADMIN": graph_node.admin_url,
            "IPFS_URL": ipfs.api_url,
        },
        run="sh /scripts/deploy_subgraph.sh sacristy/ens",
        wait="300s",
    )


def _start_bens(plan, config, graph_node, graph_postgres):
    """
    Start BENS microservice.

    BENS reads ENS data directly from graph-node's PostgreSQL database, not via
    graph-node's HTTP API. This is how it accesses indexed subgraph data.
    """
    chain_id = str(config["l1_chain_id"])
    bens_config = plan.render_templates(
        name="bens-config",
        config={
            "config.json": struct(
                template=read_file("./config.json.template"),
                data={
                    "chain_id": chain_id,
                    "registry_address": config["genesis_contracts"]["ENSRegistry"],
                },
            ),
        },
    )
    service = plan.add_service(
        name="bens",
        config=ServiceConfig(
            image=config["bens_image"],
            ports={
                "http": PortSpec(
                    number=config["port_bens_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/config": bens_config,
            },
            env_vars={
                "BENS__DATABASE__CONNECT__URL": "postgresql://graph:graph@{}:{}/graph_node".format(
                    graph_postgres.service.ip_address, graph_postgres.port,
                ),
                "BENS__DATABASE__CREATE_DATABASE": "false",
                "BENS__DATABASE__RUN_MIGRATIONS": "true",
                "BENS__SERVER__HTTP__ENABLED": "true",
                "BENS__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(config["port_bens_http"]),
                "BENS__SERVER__GRPC__ENABLED": "false",
                "BENS__CONFIG": "/config/config.json",
            },
            min_cpu=250,
            min_memory=512,
        ),
    )
    return struct(
        service=service,
        url="http://{}:{}".format(service.ip_address, config["port_bens_http"]),
    )

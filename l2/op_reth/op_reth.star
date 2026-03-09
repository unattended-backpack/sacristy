# op-reth
#
# L2 execution engine. Runs as the L2 EL client, consuming genesis.json and
# providing the Engine API for kona-node.


def start(plan, config, jwt_artifact, genesis_artifact):
    """
    Start the L2 execution engine.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        jwt_artifact: JWT secret artifact (shared with kona-node).
        genesis_artifact: L2 genesis artifact containing genesis.json.

    Returns:
        Service context with connection details.
    """
    service = plan.add_service(
        name="op-reth",
        config=ServiceConfig(
            image=config["l2_el_image"],
            ports={
                "rpc-http": PortSpec(
                    number=config["port_l2_el_rpc_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "rpc-ws": PortSpec(
                    number=config["port_l2_el_rpc_ws"],
                    transport_protocol="TCP",
                    application_protocol="ws",
                ),
                "engine": PortSpec(
                    number=config["port_l2_el_engine"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "metrics": PortSpec(
                    number=config["port_l2_el_metrics"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/genesis": genesis_artifact,
                "/secrets": jwt_artifact,
            },
            entrypoint=["/bin/sh", "-c"],
            cmd=[
                " ".join([
                    "op-reth node",
                    "--chain=/genesis/genesis.json",
                    "--datadir=$HOME/data",
                    "--http",
                    "--http.addr=0.0.0.0",
                    "--http.port={}".format(config["port_l2_el_rpc_http"]),
                    "--http.api=eth,net,web3,debug,trace,txpool",
                    "--http.corsdomain=*",
                    "--ws",
                    "--ws.addr=0.0.0.0",
                    "--ws.port={}".format(config["port_l2_el_rpc_ws"]),
                    "--ws.api=eth,net,web3,debug,trace,txpool",
                    "--ws.origins=*",
                    "--authrpc.addr=0.0.0.0",
                    "--authrpc.port={}".format(config["port_l2_el_engine"]),
                    "--authrpc.jwtsecret=/secrets/jwtsecret",
                    "--metrics=0.0.0.0:{}".format(config["port_l2_el_metrics"]),
                    "--log.stdout.format=terminal",
                ]),
            ],
            min_cpu=1000,
            min_memory=2048,
        ),
    )
    return struct(
        service=service,
        rpc_http_url="http://{}:{}".format(
            service.ip_address,
            config["port_l2_el_rpc_http"],
        ),
        rpc_ws_url="ws://{}:{}".format(
            service.ip_address,
            config["port_l2_el_rpc_ws"],
        ),
        engine_url="http://{}:{}".format(
            service.ip_address,
            config["port_l2_el_engine"],
        ),
    )

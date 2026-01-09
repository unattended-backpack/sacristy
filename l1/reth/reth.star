# Reth
#
# Reth is our execution layer client.


def start(plan, config, jwt_artifact, genesis_artifacts):
    """
    Start the execution layer node.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        jwt_artifact: JWT secret artifact from genesis generation.
        genesis_artifacts: Genesis artifacts from genesis generation.

    Returns:
        Service context with connection details.
    """
    service = plan.add_service(
        name="reth",
        config=ServiceConfig(
            image=config["l1_el_image"],
            ports={
                "rpc-http": PortSpec(
                    number=config["port_el_rpc_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "rpc-ws": PortSpec(
                    number=config["port_el_rpc_ws"],
                    transport_protocol="TCP",
                    application_protocol="ws",
                ),
                "engine": PortSpec(
                    number=config["port_el_engine"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "metrics": PortSpec(
                    number=config["port_el_metrics"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "p2p-tcp": PortSpec(
                    number=config["port_el_p2p_tcp"],
                    transport_protocol="TCP",
                ),
                "p2p-udp": PortSpec(
                    number=config["port_el_p2p_udp"],
                    transport_protocol="UDP",
                ),
            },
            files={
                "/genesis": genesis_artifacts,
                "/secrets": jwt_artifact,
            },
            entrypoint=["/bin/sh", "-c"],
            cmd=[
                " ".join([
                    "reth node",
                    "--chain=/genesis/genesis.json",
                    "--datadir=/data",
                    "--http",
                    "--http.addr=0.0.0.0",
                    "--http.port={}".format(config["port_el_rpc_http"]),
                    "--http.api=eth,net,web3,debug,trace,txpool,admin",
                    "--http.corsdomain=*",
                    "--ws",
                    "--ws.addr=0.0.0.0",
                    "--ws.port={}".format(config["port_el_rpc_ws"]),
                    "--ws.api=eth,net,web3,debug,trace,txpool",
                    "--ws.origins=*",
                    "--authrpc.addr=0.0.0.0",
                    "--authrpc.port={}".format(config["port_el_engine"]),
                    "--authrpc.jwtsecret=/secrets/jwtsecret",
                    "--metrics=0.0.0.0:{}".format(config["port_el_metrics"]),
                    "--port={}".format(config["port_el_p2p_tcp"]),
                    "--discovery.port={}".format(config["port_el_p2p_udp"]),
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
            config["port_el_rpc_http"],
        ),
        rpc_ws_url="ws://{}:{}".format(
            service.ip_address,
            config["port_el_rpc_ws"],
        ),
        engine_url="http://{}:{}".format(
            service.ip_address,
            config["port_el_engine"],
        ),
    )

# Lodestar
#
# Lodestar is our consensus layer client.

def start(plan, config, jwt_artifact, genesis_artifacts, el_context):
    """
    Start lodestar consensus layer node.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        jwt_artifact: JWT secret artifact from genesis generation.
        genesis_artifacts: Genesis artifacts from genesis generation.
        el_context: Execution layer context (for engine API connection).

    Returns:
        Service context with connection details.
    """
    service = plan.add_service(
        name="lodestar",
        config=ServiceConfig(
            image=config["l1_cl_image"],
            ports={
                "http": PortSpec(
                    number=config["port_cl_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "metrics": PortSpec(
                    number=config["port_cl_metrics"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "p2p-tcp": PortSpec(
                    number=config["port_cl_p2p_tcp"],
                    transport_protocol="TCP",
                ),
                "p2p-udp": PortSpec(
                    number=config["port_cl_p2p_udp"],
                    transport_protocol="UDP",
                ),
            },
            files={
                "/genesis": genesis_artifacts,
                "/secrets": jwt_artifact,
            },
            cmd=[
                "beacon",
                "--preset=minimal",
                "--paramsFile=/genesis/config.yaml",
                "--genesisStateFile=/genesis/genesis.ssz",
                "--dataDir=/data",
                "--execution.urls={}".format(el_context.engine_url),
                "--jwtSecret=/secrets/jwtsecret",
                "--rest=true",
                "--rest.address=0.0.0.0",
                "--rest.port={}".format(config["port_cl_http"]),
                "--rest.cors=*",
                "--metrics=true",
                "--metrics.address=0.0.0.0",
                "--metrics.port={}".format(config["port_cl_metrics"]),
                "--listenAddress=0.0.0.0",
                "--port={}".format(config["port_cl_p2p_tcp"]),
                "--discoveryPort={}".format(config["port_cl_p2p_udp"]),
                "--sync.isSingleNode=true",
                "--network.allowPublishToZeroPeers=true",
            ],
            min_cpu=1000,
            min_memory=2048,
        ),
    )
    return struct(
        service=service,
        http_url="http://{}:{}".format(
            service.ip_address,
            config["port_cl_http"],
        ),
    )

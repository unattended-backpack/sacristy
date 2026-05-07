# Sigil
#
# Unified L2 node combining execution (reth) and consensus (kona) in a single
# process. The only config file is genesis.json (via --chain). L1 connection
# details and anchor block are queried at startup from L1 RPC.


def start(plan, config, genesis_artifacts):
    """
    Start the Sigil L2 node.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        genesis_artifacts: Struct with l2_genesis.

    Returns:
        Service context with connection details.
    """
    sequencer_key = config["l2_sequencer_private_key"]

    service = plan.add_service(
        name="sigil",
        config=ServiceConfig(
            image=config["l2_node_image"],
            ports={
                "rpc-http": PortSpec(
                    number=config["port_l2_rpc_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "rpc-ws": PortSpec(
                    number=config["port_l2_rpc_ws"],
                    transport_protocol="TCP",
                    application_protocol="ws",
                ),
                "metrics": PortSpec(
                    number=config["port_l2_metrics"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/genesis": genesis_artifacts.l2_genesis,
            },
            entrypoint=["/bin/sh", "-c"],
            cmd=[
                " ".join([
                    # Set environment variables.
                    "export KONA_NODE_P2P_SEQUENCER_KEY={} &&".format(sequencer_key),

                    # Start the Sigil node.
                    "sigil node",
                    "--genesis=/genesis/genesis.json",
                    "--l1.eth-rpc {}".format(config["l1_rpc_url"]),
                    "--l1.beacon {}".format(config["l1_beacon_url"]),
                    "--l1.verifier-address {}".format(config["l2_verifier_address"]),
                    "--l1.confirmation-policy 3",
                    "--data-directory=$HOME/data",
                    "--sequencer.mode sequencer",
                    "--http",
                    "--http.address=0.0.0.0",
                    "--http.port={}".format(config["port_l2_rpc_http"]),
                    "--http.api=eth,web3,debug,trace,txpool",
                    "--http.cors=*",
                    "--ws",
                    "--ws.address=0.0.0.0",
                    "--ws.port={}".format(config["port_l2_rpc_ws"]),
                    "--ws.api=eth,web3,debug,trace,txpool",
                    "--ws.cors=*",
                    "--log.stdout.format=terminal",
                    "--metrics=0.0.0.0:{}".format(config["port_l2_metrics"]),
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
            config["port_l2_rpc_http"],
        ),
        rpc_ws_url="ws://{}:{}".format(
            service.ip_address,
            config["port_l2_rpc_ws"],
        ),
    )

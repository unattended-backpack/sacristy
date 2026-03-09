# kona-node
#
# Rollup node (sequencer). Connects to L1 for derivation and drives the L2 EL
# via the Engine API.


def start(plan, config, artifacts, l2_el):
    """
    Start the rollup node (sequencer).

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        artifacts: Genesis artifacts struct (rollup_config, l1_chain_config, jwt).
        l2_el: L2 execution engine context (from op_reth.start).

    Returns:
        Service context with connection details.
    """
    sequencer_key = config["l2_sequencer_private_key"]

    service = plan.add_service(
        name="kona-node",
        config=ServiceConfig(
            image=config["l2_node_image"],
            ports={
                "rpc": PortSpec(
                    number=config["port_l2_node_rpc"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "metrics": PortSpec(
                    number=config["port_l2_node_metrics"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/config": artifacts.rollup_config,
                "/l1config": artifacts.l1_chain_config,
                "/secrets": artifacts.jwt,
            },
            entrypoint=["/bin/sh", "-c"],
            cmd=[
                " ".join([
                    # Read JWT and sequencer key from files/env, then exec the node.
                    "export KONA_NODE_L2_ENGINE_AUTH_ENCODED=$(cat /secrets/jwtsecret) &&",
                    "export KONA_NODE_P2P_SEQUENCER_KEY={} &&".format(sequencer_key),
                    "kona-node node",
                    "--mode sequencer",
                    "--chain {}".format(config["l2_chain_id"]),
                    "--l1-eth-rpc {}".format(config["l1_rpc_url"]),
                    "--l1-beacon {}".format(config["l1_beacon_url"]),
                    "--l2-engine-rpc {}".format(l2_el.engine_url),
                    "--l2-rpc-url {}".format(l2_el.rpc_http_url),
                    "--rollup-cfg /config/rollup_config.json",
                    "--rollup-l1-cfg /l1config/l1_chain_config.json",
                    "--p2p.no-discovery",
                    "--rpc.addr 0.0.0.0",
                    "--rpc.port {}".format(config["port_l2_node_rpc"]),
                    "--rpc.enable-admin",
                    "--metrics.enabled",
                    "--metrics.port {}".format(config["port_l2_node_metrics"]),
                    "--sequencer.l1-confs 0",
                ]),
            ],
            min_cpu=500,
            min_memory=1024,
        ),
    )
    return struct(
        service=service,
        rpc_url="http://{}:{}".format(
            service.ip_address,
            config["port_l2_node_rpc"],
        ),
    )

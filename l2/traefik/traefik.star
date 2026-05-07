# Traefik (L2)
#
# Reverse proxy for local DNS-like access to L2 services. Provides stable
# hostnames so that tools like the test harness don't need reconfiguration
# when the L2 enclave is torn down and restarted.


def start(plan, config, sigil_context, blockscout_context=None):
    """
    Start Traefik reverse proxy with routes for L2 services.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        sigil_context: Sigil service context (provides EL RPC).
        blockscout_context: Optional Blockscout explorer context.

    Returns:
        Service context with access URLs.
    """

    # Render static config.
    static_config = plan.render_templates(
        name="l2-traefik-static-config",
        config={
            "traefik.yaml": struct(
                template=read_file("./static.yaml"),
                data={
                    "HttpPort": config["port_traefik_http"],
                    "DashboardPort": config["port_traefik_dashboard"],
                },
            ),
        },
    )

    # Build template data.
    template_data = {
        "RpcHost": sigil_context.service.ip_address,
        "RpcPort": config["port_l2_rpc_http"],

        # Optional services. Empty string disables the route in the template.
        "BlockscoutHost": blockscout_context.frontend.ip_address if blockscout_context else "",
        "BlockscoutPort": config["port_blockscout_frontend"] if blockscout_context else "",
        "BlockscoutApiHost": blockscout_context.backend.ip_address if blockscout_context else "",
        "BlockscoutApiPort": config["port_blockscout_http"] if blockscout_context else "",
    }

    # Render dynamic config with service addresses.
    dynamic_config = plan.render_templates(
        name="l2-traefik-dynamic-config",
        config={
            "dynamic.yaml": struct(
                template=read_file("./dynamic.yaml"),
                data=template_data,
            ),
        },
    )

    service = plan.add_service(
        name="l2-traefik",
        config=ServiceConfig(
            image=config["traefik_image"],
            ports={
                "http": PortSpec(
                    number=config["port_traefik_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "dashboard": PortSpec(
                    number=config["port_traefik_dashboard"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/etc/traefik": Directory(
                    artifact_names=[static_config, dynamic_config],
                ),
            },
            cmd=[
                "--configFile=/etc/traefik/traefik.yaml",
            ],
            min_cpu=100,
            min_memory=128,
        ),
    )

    return struct(
        service=service,
        http_port=config["port_traefik_http"],
        dashboard_url="http://{}:{}".format(
            service.ip_address,
            config["port_traefik_dashboard"],
        ),
        hosts={
            "rpc": "rpc.l2.sacristy.local",
            "blockscout": "blockscout.l2.sacristy.local",
            "blockscout_api": "api.blockscout.l2.sacristy.local",
        },
    )

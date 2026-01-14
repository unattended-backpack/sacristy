# Traefik
#
# Reverse proxy for local DNS-like access. Provides stable hostnames for all
# services to make local development work significantly easier.


def start(
    plan,
    config,
    el_context,
    cl_context,
    dora_context=None,
    blockscout_context=None,
    blobscan_context=None,
    monitoring_context=None,
):
    """
    Start Traefik reverse proxy with routes for all explorer services.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: Execution layer context (required).
        cl_context: Consensus layer context (required).
        dora_context: Optional Dora explorer context.
        blockscout_context: Optional Blockscout explorer context (includes BENS if enabled).
        blobscan_context: Optional Blobscan explorer context.
        monitoring_context: Optional Prometheus and Grafana context.

    Returns:
        Service context with access URLs.
    """

    # Extract BENS context from blockscout if available.
    bens_context = blockscout_context.bens if blockscout_context else None

    # Render static config.
    static_config = plan.render_templates(
        name="traefik-static-config",
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

    # Build template data. RPC and beacon are always available.
    template_data = {
        "RpcHost": el_context.service.ip_address,
        "RpcPort": config["port_el_rpc_http"],
        "BeaconHost": cl_context.service.ip_address,
        "BeaconPort": config["port_cl_http"],

        # Optional services. Empty string disables the route in the template.
        "DoraHost": dora_context.service.ip_address if dora_context else "",
        "DoraPort": config["port_dora_http"] if dora_context else "",
        "BlockscoutHost": blockscout_context.frontend.ip_address if blockscout_context else "",
        "BlockscoutPort": config["port_blockscout_frontend"] if blockscout_context else "",
        "BlockscoutApiHost": blockscout_context.backend.ip_address if blockscout_context else "",
        "BlockscoutApiPort": config["port_blockscout_http"] if blockscout_context else "",
        "BlobscanHost": blobscan_context.web.ip_address if blobscan_context else "",
        "BlobscanPort": config["port_blobscan_web"] if blobscan_context else "",
        "PrometheusHost": monitoring_context.prometheus.service.ip_address if monitoring_context else "",
        "PrometheusPort": config["port_prometheus_http"] if monitoring_context else "",
        "GrafanaHost": monitoring_context.grafana.service.ip_address if monitoring_context else "",
        "GrafanaPort": config["port_grafana_http"] if monitoring_context else "",
        "BensHost": bens_context.bens.service.ip_address if bens_context else "",
        "BensPort": config["port_bens_http"] if bens_context else "",
    }

    # Render dynamic config with service addresses.
    dynamic_config = plan.render_templates(
        name="traefik-dynamic-config",
        config={
            "dynamic.yaml": struct(
                template=read_file("./dynamic.yaml"),
                data=template_data,
            ),
        },
    )
    service = plan.add_service(
        name="traefik",
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
            "dora": "dora.sacristy.local",
            "blockscout": "blockscout.sacristy.local",
            "blockscout_api": "api.blockscout.sacristy.local",
            "blobscan": "blobscan.sacristy.local",
            "rpc": "rpc.sacristy.local",
            "beacon": "beacon.sacristy.local",
            "prometheus": "prometheus.sacristy.local",
            "grafana": "grafana.sacristy.local",
            "bens": "bens.sacristy.local",
        },
    )

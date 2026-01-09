# Dora, so we can see the consensus layer.
#
# Dora is a lightweight Ethereum beacon chain explorer.

def start(plan, config, genesis_artifacts, cl_context):
    """
    Start tje Dora beacon chain explorer.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        genesis_artifacts: Genesis artifacts (contains config.yaml).
        cl_context: Consensus layer context (beacon node connection).

    Returns:
        Service context with Dora web UI URL.
    """
    config_artifact = plan.render_templates(
        name="dora-config",
        description="Rendering Dora config template",
        config={
            "config.yaml": struct(
                template=read_file("./config.yaml.template"),
                data={
                    "Port": config["port_dora_http"],
                    "BeaconUrl": cl_context.http_url,
                },
            ),
        },
    )

    # Start Dora.
    service = plan.add_service(
        name="dora",
        config=ServiceConfig(
            image=config["dora_image"],
            ports={
                "http": PortSpec(
                    number=config["port_dora_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/config": config_artifact,
                "/genesis": genesis_artifacts,
            },
            cmd=[
                "-config=/config/config.yaml",
            ],
            min_cpu=250,
            min_memory=512,
        ),
    )
    return struct(
        service=service,
        http_url="http://{}:{}".format(
            service.ip_address,
            config["port_dora_http"],
        ),
    )

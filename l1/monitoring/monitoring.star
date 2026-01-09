# Prometheus and Grafana monitoring stack.
#
# Scrapes metrics from all services and provides visualization.

def start(plan, config, el_context, cl_context, validator_context):
    """
    Start Prometheus and Grafana for metrics collection and visualization.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: Execution layer context.
        cl_context: Consensus layer context.
        validator_context: Validator context.

    Returns:
        Struct with prometheus and grafana service contexts.
    """
    prometheus = _start_prometheus(
        plan, config, el_context, cl_context, validator_context
    )
    grafana = _start_grafana(plan, config, prometheus)
    return struct(
        prometheus=prometheus,
        grafana=grafana,
    )


def _start_prometheus(plan, config, el_context, cl_context, validator_context):
    """Start Prometheus metrics collector."""
    config_artifact = plan.render_templates(
        name="prometheus-config",
        description="Rendering Prometheus config",
        config={
            "prometheus.yml": struct(
                template=read_file("./prometheus.yaml.template"),
                data={
                    "ElHost": el_context.service.ip_address,
                    "ElMetricsPort": config["port_el_metrics"],
                    "ClHost": cl_context.service.ip_address,
                    "ClMetricsPort": config["port_cl_metrics"],
                    "ValidatorHost": validator_context.service.ip_address,
                    "ValidatorMetricsPort": config["port_validator_metrics"],
                    "PrometheusPort": config["port_prometheus_http"],
                },
            ),
        },
    )
    service = plan.add_service(
        name="prometheus",
        config=ServiceConfig(
            image=config["prometheus_image"],
            ports={
                "http": PortSpec(
                    number=config["port_prometheus_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/etc/prometheus": config_artifact,
            },
            cmd=[
                "--config.file=/etc/prometheus/prometheus.yml",
                "--storage.tsdb.path=/prometheus",
                "--web.console.libraries=/usr/share/prometheus/console_libraries",
                "--web.console.templates=/usr/share/prometheus/consoles",
                "--web.enable-lifecycle",
            ],
            min_cpu=250,
            min_memory=512,
        ),
    )
    return struct(
        service=service,
        url="http://{}:{}".format(
            service.ip_address,
            config["port_prometheus_http"],
        ),
    )


def _start_grafana(plan, config, prometheus):
    """Start Grafana visualization."""
    datasource_artifact = plan.render_templates(
        name="grafana-datasources",
        description="Rendering Grafana datasources config",
        config={
            "datasources.yaml": struct(
                template=read_file("./grafana-datasources.yaml.template"),
                data={
                    "PrometheusUrl": prometheus.url,
                },
            ),
        },
    )
    service = plan.add_service(
        name="grafana",
        config=ServiceConfig(
            image=config["grafana_image"],
            ports={
                "http": PortSpec(
                    number=config["port_grafana_http"],
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/etc/grafana/provisioning/datasources": datasource_artifact,
            },
            env_vars={
                "GF_AUTH_ANONYMOUS_ENABLED": "true",
                "GF_AUTH_ANONYMOUS_ORG_ROLE": "Admin",
                "GF_AUTH_DISABLE_LOGIN_FORM": "true",
                "GF_SERVER_ROOT_URL": "http://grafana.sacristy.local",
            },
            min_cpu=250,
            min_memory=256,
        ),
    )
    return struct(
        service=service,
        url="http://{}:{}".format(
            service.ip_address,
            config["port_grafana_http"],
        ),
    )

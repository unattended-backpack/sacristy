# Bootstrap EIP-7702 Delegation
#
# Sets up EIP-7702 delegation for all accounts to MulticallDelegate.
# After this runs, each account has multicall capability and downstream
# scripts can use normal Foundry patterns to batch operations.


def bootstrap(plan, config, el_context):
    """
    Set up EIP-7702 delegation for all accounts.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: Execution layer context (for RPC endpoint).
    """
    delegate_addr = config["genesis_contracts"]["MulticallDelegate"]
    rpc_url = "http://{}:{}".format(
        el_context.service.ip_address,
        config["port_el_rpc_http"],
    )
    num_accounts = len(config["accounts"])

    # Render and run the delegation script.
    script_artifact = plan.render_templates(
        name="delegate-script",
        config={
            "delegate.sh": struct(
                template=read_file("./delegate.sh"),
                data={},
            ),
        },
    )
    plan.run_sh(
        name="setup-7702-delegation",
        description="Setting up 7702 delegation for {} accounts".format(num_accounts),
        image=config["foundry_image"],
        files={
            "/scripts": script_artifact,
        },
        env_vars={
            "FOUNDRY_DISABLE_NIGHTLY_WARNING": "1",
            "MNEMONIC": config["mnemonic"],
            "DELEGATE": delegate_addr,
            "RPC": rpc_url,
            "NUM_ACCOUNTS": str(num_accounts),
        },
        run="sh /scripts/delegate.sh",
    )

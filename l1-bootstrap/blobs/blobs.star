# Bootstrap Blobs
#
# Send a blob transaction for each configured account.

def bootstrap(plan, config, el_context):
    """
    Send blob transactions for each configured account.

    Private keys are derived from the mnemonic at runtime.
    Blob data is the hex-encoded account name.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        el_context: Execution layer context (RPC connection).

    Returns:
        List of transaction results.
    """
    accounts = config.get("accounts", [])
    if len(accounts) == 0:
        return []
    mnemonic = config["mnemonic"]
    rpc_url = "http://{}:{}".format(
        el_context.service.ip_address,
        config["port_el_rpc_http"],
    )

    # Render the blob script.
    script_artifact = plan.render_templates(
        name="render-blob-script",
        config={
            "post_blob.sh": struct(
                template=read_file("./post_blob.sh"),
                data={},
            ),
        },
    )
    results = []
    for i, account in enumerate(accounts):
        name = account["name"]
        result = plan.run_sh(
            name="post-blob-{}".format(name),
            description="Posting blob: {}".format(name),
            image=config["foundry_image"],
            files={
                "/scripts": script_artifact,
            },
            env_vars={
                "RPC_URL": rpc_url,
                "MNEMONIC": mnemonic,
                "MNEMONIC_INDEX": str(i),
                "ACCOUNT_NAME": name,
            },
            run="bash /scripts/post_blob.sh",
        )
        results.append(result)
    return results

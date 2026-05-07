# Batcher
#
# Reads L2 blocks from the Sigil node and posts them as 254-bit-packed
# blobs to L1 by calling `postBlobs()` on the SigilVerifier. Sigil has
# no separate batch inbox — the verifier IS the inbox.


def start(plan, config, sigil):
    """
    Start the batch submitter.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        sigil: Sigil service context (provides EL RPC).

    Returns:
        Service context.
    """
    service = plan.add_service(
        name="batcher",
        config=ServiceConfig(
            image=config["l2_batcher_image"],
            entrypoint=["/bin/sh", "-c"],
            cmd=[
                " ".join([
                    "batcher",
                    "--l2-rpc-url {}".format(sigil.rpc_http_url),
                    "--l1-rpc-url {}".format(config["l1_rpc_url"]),
                    "--verifier-address {}".format(config["l2_verifier_address"]),
                    "--fee-recipient {}".format(config["l2_fee_recipient"]),
                    "--private-key {}".format(config["l2_batcher_private_key"]),
                ]),
            ],
            min_cpu=250,
            min_memory=512,
        ),
    )
    return struct(
        service=service,
    )

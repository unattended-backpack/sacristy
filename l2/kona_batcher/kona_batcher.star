# kona-batcher
#
# Batch submitter. Reads L2 blocks from op-reth and submits them as batches
# to the L1 batch inbox address.


def start(plan, config, l2_el):
    """
    Start the batch submitter.

    Args:
        plan: Kurtosis plan.
        config: Configuration.
        l2_el: L2 execution engine context (from op_reth.start).

    Returns:
        Service context.
    """
    service = plan.add_service(
        name="kona-batcher",
        config=ServiceConfig(
            image=config["l2_batcher_image"],
            entrypoint=["/bin/sh", "-c"],
            cmd=[
                " ".join([
                    "kona-batcher",
                    "--l2-rpc-url {}".format(l2_el.rpc_http_url),
                    "--l1-rpc-url {}".format(config["l1_rpc_url"]),
                    "--batch-inbox {}".format(config["l2_batch_inbox_address"]),
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

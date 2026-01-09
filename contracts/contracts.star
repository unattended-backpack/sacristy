# Contracts compiled for later use.
#
# Compiles all contracts in src/ and makes artifacts available for use by other
# modules (genesis predeployment, subgraph indexing, script execution, etc.).

def build(plan, config):
    """
    Compile all contracts and return artifacts.

    Returns a struct containing:
        - out: artifact with compiled contract files (ABI, bytecode, etc.)
        - lib: artifact with installed dependencies (forge-std, etc.)

    The out/ directory structure mirrors Forge output:
        `out/ContractName.sol/ContractName.json`

    Each JSON file contains: abi, bytecode, deployedBytecode, etc.
    """

    # Upload the entire contracts directory.
    source_artifact = plan.upload_files(
        src="./src",
        name="contracts-src",
    )
    script_artifact = plan.upload_files(
        src="./script",
        name="contracts-script",
    )
    foundry_artifact = plan.upload_files(
        src="./foundry.toml",
        name="contracts-foundry-toml",
    )

    # Install dependencies and compile.
    # Note: Kurtosis artifacts are mounted read-only and owned by root.
    # The foundry image runs as non-root user, so we must copy to a writable
    # location before building (forge needs to install solc to ~/.svm).
    result = plan.run_sh(
        name="compile-contracts",
        description="Installing dependencies and compiling contracts",
        image=config["foundry_image"],
        files={
            "/mnt/src": source_artifact,
            "/mnt/script": script_artifact,
            "/mnt/config": foundry_artifact,
        },
        env_vars={
            "FOUNDRY_DISABLE_NIGHTLY_WARNING": "1",
        },
        store=[
            StoreSpec(src="/tmp/build/out", name="contracts-out"),
            StoreSpec(src="/tmp/build/dependencies", name="contracts-lib"),
        ],
        run=(
            "mkdir -p /tmp/build && " +
            "cp -r /mnt/src /tmp/build/src && " +
            "cp -r /mnt/script /tmp/build/script && " +
            "cp /mnt/config/foundry.toml /tmp/build/foundry.toml && " +
            "cd /tmp/build && " +
            "forge soldeer install && " +
            "forge build"
        ),
    )
    return struct(
        out=result.files_artifacts[0],
        lib=result.files_artifacts[1],
    )

// SPDX-License-Identifier: MIT

// SigilVerifier requires solc ≥ 0.8.24 for the `blobhash` opcode.
pragma solidity ^0.8.25;

import { Script, console } from "forge-std/Script.sol";

import { SigilVerifier } from "src/l2/verifier/SigilVerifier.sol";
import { ISP1Verifier } from "src/l2/verifier/ISP1Verifier.sol";

/// @title DeployL2Contracts
/// @notice Deploys the L1 contracts for a Sigil rollup. Sigil collapses the
///         OP-stack-style BlobRegistry + DepositQueue + Verifier + Portal
///         into one contract — see `optimism/NEW_DERIVATION.md` for the
///         design doc and `src/l2/verifier/SigilVerifier.sol` for the
///         contract.
///
///         Usage:
///           forge script script/DeployL2Contracts.s.sol \
///             --rpc-url $L1_RPC --private-key $ADMIN_KEY --broadcast
///
///         All environment variables are REQUIRED — no defaults, since
///         silently deploying with a placeholder zkVM verifier or zero
///         genesis root would be a footgun:
///           L2_CHAIN_ID                 - L2 chain id.
///           L1_CHAIN_ID                 - L1 chain id this L2 settles to.
///           GENESIS_TIMESTAMP           - L2 genesis block Unix-seconds
///                                         timestamp.
///           GENESIS_ACCOUNTS_FILE       - Path to a binary file
///                                         containing the zstd-compressed
///                                         RLP encoding of the genesis
///                                         accounts (`sigil genesis`
///                                         emits it). Lands in
///                                         deployment-tx calldata for
///                                         off-chain validator retrieval.
///           L2_MINIMUM_BLOCK_GAS_LIMIT  - Floor on the per-block gas
///                                         limit. Sequencers may pick
///                                         any per-blob ceiling above
///                                         this value.
///           L2_MINIMUM_TX_GAS_LIMIT     - Floor on the per-tx gas-limit
///                                         cap (`cfg_env.tx_gas_limit_cap`).
///                                         Default is EIP-7825 Osaka:
///                                         16,777,216 = 2^24.
///           L2_MINIMUM_CODE_SIZE        - Floor on the per-blob EIP-170
///                                         deployed-code cap. Default
///                                         24,576.
///           L2_MAXIMUM_CODE_SIZE        - Ceiling on the per-blob EIP-170
///                                         deployed-code cap. Set equal
///                                         to the floor to pin, or higher
///                                         to grant sequencer policy
///                                         diversity within a range.
///           L2_MINIMUM_INITCODE_SIZE    - Floor on the per-blob EIP-3860
///                                         initcode cap. Default 49,152.
///           L2_MAXIMUM_INITCODE_SIZE    - Ceiling on the per-blob EIP-3860
///                                         initcode cap.
///           L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE
///                                       - Ceiling on the per-action
///                                         `Call.calldata` size for
///                                         sequencer-space pre-execution
///                                         calls. Default 65,536 bytes.
///           PROVER_QUORUM               - Minimum distinct zkVM systems
///                                         (1 for single-system testnet,
///                                         ≥ 2 for production).
///           SP1_VERIFIER        - Address of the SP1 verifier contract.
///                                 Use the zero address explicitly to
///                                 disable on-chain verification on a
///                                 testnet — `SigilVerifier.submitProof`
///                                 then skips the SP1 check.
///           SP1_VKEY            - SP1 verification key.
///           GENESIS_OUTPUT_ROOT - L2 genesis output root.
contract DeployL2Contracts is Script {
  function run() public {
    uint64 chainId = uint64(vm.envUint("L2_CHAIN_ID"));
    uint64 l1ChainId = uint64(vm.envUint("L1_CHAIN_ID"));
    uint64 genesisTimestamp = uint64(vm.envUint("GENESIS_TIMESTAMP"));
    bytes memory accountsData = vm.readFileBinary(
      vm.envString("GENESIS_ACCOUNTS_FILE")
    );
    uint64 minimumBlockGasLimit =
      uint64(vm.envUint("L2_MINIMUM_BLOCK_GAS_LIMIT"));
    uint64 minimumTxGasLimit =
      uint64(vm.envUint("L2_MINIMUM_TX_GAS_LIMIT"));
    uint64 minimumCodeSize =
      uint64(vm.envUint("L2_MINIMUM_CODE_SIZE"));
    uint64 maximumCodeSize =
      uint64(vm.envUint("L2_MAXIMUM_CODE_SIZE"));
    uint64 minimumInitcodeSize =
      uint64(vm.envUint("L2_MINIMUM_INITCODE_SIZE"));
    uint64 maximumInitcodeSize =
      uint64(vm.envUint("L2_MAXIMUM_INITCODE_SIZE"));
    uint64 maximumSequencerCalldataSize =
      uint64(vm.envUint("L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE"));
    uint8 quorum = uint8(vm.envUint("PROVER_QUORUM"));
    address sp1Verifier = vm.envAddress("SP1_VERIFIER");
    bytes32 sp1Vkey = vm.envBytes32("SP1_VKEY");
    bytes32 genesisOutputRoot = vm.envBytes32("GENESIS_OUTPUT_ROOT");

    vm.startBroadcast();

    // Single-system testnet deployment: the SP1 verifier is the only
    // system in the quorum. Production deployments would seed a
    // quorum of ≥ 2 distinct zkVM verifiers (SP1 + RISC Zero + ...).
    address[] memory verifiers = new address[](1);
    verifiers[0] = sp1Verifier;
    bytes32[] memory vkeys = new bytes32[](1);
    vkeys[0] = sp1Vkey;

    SigilVerifier verifier = new SigilVerifier(
      chainId,
      l1ChainId,
      genesisTimestamp,
      minimumBlockGasLimit,
      minimumTxGasLimit,
      minimumCodeSize,
      maximumCodeSize,
      minimumInitcodeSize,
      maximumInitcodeSize,
      maximumSequencerCalldataSize,
      accountsData,
      verifiers,
      vkeys,
      quorum,
      genesisOutputRoot
    );
    console.log("SigilVerifier:", address(verifier));

    vm.stopBroadcast();

    console.log("");
    console.log("=== Deployed Sigil Contracts ===");
    console.log("sigil_verifier:", address(verifier));
    console.log("chain_id:", uint256(chainId));
    console.log("l1_chain_id:", uint256(l1ChainId));
    console.log("genesis_timestamp:", uint256(genesisTimestamp));
    console.log("accounts_data_bytes:", accountsData.length);
    console.log("minimum_block_gas_limit:", uint256(minimumBlockGasLimit));
    console.log("minimum_tx_gas_limit:", uint256(minimumTxGasLimit));
    console.log("minimum_code_size:", uint256(minimumCodeSize));
    console.log("maximum_code_size:", uint256(maximumCodeSize));
    console.log("minimum_initcode_size:", uint256(minimumInitcodeSize));
    console.log("maximum_initcode_size:", uint256(maximumInitcodeSize));
    console.log(
      "maximum_sequencer_calldata_size:",
      uint256(maximumSequencerCalldataSize)
    );
    console.log("quorum:", uint256(quorum));
  }
}

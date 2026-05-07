// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Script } from "forge-std/Script.sol";

// Predeploy contracts. Sigil drops the OP-stack predeploys whose
// purpose was tracking L1 conditions on L2 (`L1Block`, `GasPriceOracle`,
// `BaseFeeVault`, `L1FeeVault`, `SequencerFeeVault`) — see
// `optimism/NEW_DERIVATION.md` §"No `L1Block` predeploy" and
// "No EIP-1559 base fee" and "Per-blob `fee_recipient`".
import { L2ToL1MessagePasser } from "src/l2/predeploys/L2ToL1MessagePasser.sol";
import { L2CrossDomainMessenger } from "src/l2/predeploys/L2CrossDomainMessenger.sol";
import { L2StandardBridge } from "src/l2/predeploys/L2StandardBridge.sol";
import { L2ERC721Bridge } from "src/l2/predeploys/L2ERC721Bridge.sol";
import { OptimismMintableERC20Factory } from "src/l2/predeploys/OptimismMintableERC20Factory.sol";
import { OptimismMintableERC721Factory } from "src/l2/predeploys/OptimismMintableERC721Factory.sol";
import { GovernanceToken } from "src/l2/predeploys/GovernanceToken.sol";
import { EAS } from "src/l2/predeploys/EAS.sol";
import { SchemaRegistry } from "src/l2/predeploys/SchemaRegistry.sol";
import { Proxy } from "src/l2/predeploys/Proxy.sol";
import { BlockTimestampMs } from "src/l2/predeploys/BlockTimestampMs.sol";

/// @title GenerateL2Genesis
/// @notice Forge script that deploys all L2 predeploy contracts in the Forge EVM, then dumps the
///         state as an accounts JSON. The accounts file is consumed by build_genesis.sh to
///         produce the full genesis.json.
///
///         Usage:
///           forge script script/GenerateL2Genesis.s.sol --sig "run(address)" $ADMIN
contract GenerateL2Genesis is Script {
    /// @notice Canonical predeploy addresses. Sigil keeps the OP-stack
    ///         addresses for predeploys it preserves (bridges, message
    ///         passer, attestation, governance, mintable factories) so
    ///         existing OP-stack tooling still finds them at the same
    ///         spots; the L1-condition-tracking predeploys are absent.
    address constant L2_TO_L1_MESSAGE_PASSER = 0x4200000000000000000000000000000000000016;
    address constant L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
    address constant L2_STANDARD_BRIDGE    = 0x4200000000000000000000000000000000000010;
    address constant OPTIMISM_MINTABLE_ERC20_FACTORY = 0x4200000000000000000000000000000000000012;
    address constant L2_ERC721_BRIDGE      = 0x4200000000000000000000000000000000000014;
    address constant OPTIMISM_MINTABLE_ERC721_FACTORY = 0x4200000000000000000000000000000000000017;
    address constant SCHEMA_REGISTRY       = 0x4200000000000000000000000000000000000020;
    address constant EAS_PREDEPLOY         = 0x4200000000000000000000000000000000000021;
    address constant GOVERNANCE_TOKEN      = 0x4200000000000000000000000000000000000042;
    /// @notice Sigil-specific predeploy: ms wall-time updated by the
    ///         STF as a pre-execution change. See
    ///         `primitives::consensus::predeploys::BLOCK_TIMESTAMP_MS_ADDRESS`.
    address constant BLOCK_TIMESTAMP_MS    = 0x4200000000000000000000000000000000000050;

    /// @notice ERC-1967 storage slots.
    bytes32 constant IMPL_SLOT  = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run(address _admin) public {
        // Deploy all predeploys. For each:
        // 1. Deploy the implementation at an arbitrary address.
        // 2. Etch the Proxy bytecode at the canonical predeploy address.
        // 3. Set the ERC-1967 impl and admin slots.

        _deployPredeploy(L2_TO_L1_MESSAGE_PASSER, type(L2ToL1MessagePasser).runtimeCode, _admin);
        _deployPredeploy(L2_CROSS_DOMAIN_MESSENGER, type(L2CrossDomainMessenger).runtimeCode, _admin);
        _deployPredeploy(L2_STANDARD_BRIDGE, type(L2StandardBridge).runtimeCode, _admin);
        _deployPredeploy(OPTIMISM_MINTABLE_ERC20_FACTORY, type(OptimismMintableERC20Factory).runtimeCode, _admin);
        _deployPredeploy(L2_ERC721_BRIDGE, type(L2ERC721Bridge).runtimeCode, _admin);
        _deployPredeploy(OPTIMISM_MINTABLE_ERC721_FACTORY, type(OptimismMintableERC721Factory).runtimeCode, _admin);
        _deployPredeploy(SCHEMA_REGISTRY, type(SchemaRegistry).runtimeCode, _admin);
        _deployPredeploy(EAS_PREDEPLOY, type(EAS).runtimeCode, _admin);
        _deployPredeploy(GOVERNANCE_TOKEN, type(GovernanceToken).runtimeCode, _admin);
        _deployPredeploy(BLOCK_TIMESTAMP_MS, type(BlockTimestampMs).runtimeCode, _admin);

        // Dump the state to a JSON file for consumption by build_genesis.sh.
        vm.dumpState("/tmp/accounts.json");
    }

    /// @notice Deploy implementation bytecode at the canonical predeploy address.
    ///         Uses vm.etch to place the runtime bytecode directly (skipping proxy pattern
    ///         for simplicity — all predeploy bytecode is directly at the canonical address).
    function _deployPredeploy(address _addr, bytes memory _code, address _admin) internal {
        vm.etch(_addr, _code);
        // Set ERC-1967 admin slot so the proxy admin can upgrade later.
        vm.store(_addr, ADMIN_SLOT, bytes32(uint256(uint160(_admin))));
    }
}

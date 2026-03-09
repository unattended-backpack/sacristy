// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Script } from "forge-std/Script.sol";

// Predeploy contracts.
import { L1Block } from "src/l2/predeploys/L1Block.sol";
import { GasPriceOracle } from "src/l2/predeploys/GasPriceOracle.sol";
import { L2ToL1MessagePasser } from "src/l2/predeploys/L2ToL1MessagePasser.sol";
import { L2CrossDomainMessenger } from "src/l2/predeploys/L2CrossDomainMessenger.sol";
import { L2StandardBridge } from "src/l2/predeploys/L2StandardBridge.sol";
import { L2ERC721Bridge } from "src/l2/predeploys/L2ERC721Bridge.sol";
import { SequencerFeeVault } from "src/l2/predeploys/SequencerFeeVault.sol";
import { BaseFeeVault } from "src/l2/predeploys/BaseFeeVault.sol";
import { L1FeeVault } from "src/l2/predeploys/L1FeeVault.sol";
import { OptimismMintableERC20Factory } from "src/l2/predeploys/OptimismMintableERC20Factory.sol";
import { OptimismMintableERC721Factory } from "src/l2/predeploys/OptimismMintableERC721Factory.sol";
import { GovernanceToken } from "src/l2/predeploys/GovernanceToken.sol";
import { EAS } from "src/l2/predeploys/EAS.sol";
import { SchemaRegistry } from "src/l2/predeploys/SchemaRegistry.sol";
import { Proxy } from "src/l2/predeploys/Proxy.sol";

/// @title GenerateL2Genesis
/// @notice Forge script that deploys all L2 predeploy contracts in the Forge EVM, then dumps the
///         state as an alloc JSON. The alloc is consumed by build_genesis.sh to produce the
///         full genesis.json for op-reth.
///
///         Usage:
///           forge script script/GenerateL2Genesis.s.sol --sig "run(address)" $ADMIN
contract GenerateL2Genesis is Script {
    /// @notice Canonical predeploy addresses.
    address constant L2_TO_L1_MESSAGE_PASSER = 0x4200000000000000000000000000000000000016;
    address constant L1_BLOCK              = 0x4200000000000000000000000000000000000015;
    address constant L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
    address constant L2_STANDARD_BRIDGE    = 0x4200000000000000000000000000000000000010;
    address constant SEQUENCER_FEE_VAULT   = 0x4200000000000000000000000000000000000011;
    address constant OPTIMISM_MINTABLE_ERC20_FACTORY = 0x4200000000000000000000000000000000000012;
    address constant L2_ERC721_BRIDGE      = 0x4200000000000000000000000000000000000014;
    address constant OPTIMISM_MINTABLE_ERC721_FACTORY = 0x4200000000000000000000000000000000000017;
    address constant GAS_PRICE_ORACLE      = 0x420000000000000000000000000000000000000F;
    address constant BASE_FEE_VAULT        = 0x4200000000000000000000000000000000000019;
    address constant L1_FEE_VAULT          = 0x420000000000000000000000000000000000001A;
    address constant SCHEMA_REGISTRY       = 0x4200000000000000000000000000000000000020;
    address constant EAS_PREDEPLOY         = 0x4200000000000000000000000000000000000021;
    address constant GOVERNANCE_TOKEN      = 0x4200000000000000000000000000000000000042;

    /// @notice ERC-1967 storage slots.
    bytes32 constant IMPL_SLOT  = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run(address _admin) public {
        // Deploy all predeploys. For each:
        // 1. Deploy the implementation at an arbitrary address.
        // 2. Etch the Proxy bytecode at the canonical predeploy address.
        // 3. Set the ERC-1967 impl and admin slots.

        _deployPredeploy(L1_BLOCK, type(L1Block).runtimeCode, _admin);
        _deployPredeploy(GAS_PRICE_ORACLE, type(GasPriceOracle).runtimeCode, _admin);
        _deployPredeploy(L2_TO_L1_MESSAGE_PASSER, type(L2ToL1MessagePasser).runtimeCode, _admin);
        _deployPredeploy(L2_CROSS_DOMAIN_MESSENGER, type(L2CrossDomainMessenger).runtimeCode, _admin);
        _deployPredeploy(L2_STANDARD_BRIDGE, type(L2StandardBridge).runtimeCode, _admin);
        _deployPredeploy(SEQUENCER_FEE_VAULT, type(SequencerFeeVault).runtimeCode, _admin);
        _deployPredeploy(OPTIMISM_MINTABLE_ERC20_FACTORY, type(OptimismMintableERC20Factory).runtimeCode, _admin);
        _deployPredeploy(L2_ERC721_BRIDGE, type(L2ERC721Bridge).runtimeCode, _admin);
        _deployPredeploy(OPTIMISM_MINTABLE_ERC721_FACTORY, type(OptimismMintableERC721Factory).runtimeCode, _admin);
        _deployPredeploy(BASE_FEE_VAULT, type(BaseFeeVault).runtimeCode, _admin);
        _deployPredeploy(L1_FEE_VAULT, type(L1FeeVault).runtimeCode, _admin);
        _deployPredeploy(SCHEMA_REGISTRY, type(SchemaRegistry).runtimeCode, _admin);
        _deployPredeploy(EAS_PREDEPLOY, type(EAS).runtimeCode, _admin);
        _deployPredeploy(GOVERNANCE_TOKEN, type(GovernanceToken).runtimeCode, _admin);

        // Dump the state to a JSON file for consumption by build_genesis.sh.
        vm.dumpState("/tmp/alloc.json");
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

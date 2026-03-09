// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000020
/// @title SchemaRegistry
/// @notice EAS Schema Registry. Stub for testnet genesis.
contract SchemaRegistry {
    function version() public pure returns (string memory) { return "1.3.0"; }
}

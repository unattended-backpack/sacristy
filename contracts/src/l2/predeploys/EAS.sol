// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000021
/// @title EAS
/// @notice Ethereum Attestation Service. Stub for testnet genesis.
contract EAS {
    function version() public pure returns (string memory) { return "1.4.0"; }
}

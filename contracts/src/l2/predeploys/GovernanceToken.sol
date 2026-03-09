// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000042
/// @title GovernanceToken
/// @notice The OP governance token. Stub for testnet genesis.
contract GovernanceToken {
    string public constant name = "Optimism";
    string public constant symbol = "OP";
    uint8 public constant decimals = 18;

    function version() public pure returns (string memory) { return "1.1.0"; }
}

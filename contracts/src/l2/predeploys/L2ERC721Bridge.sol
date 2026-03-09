// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000014
/// @title L2ERC721Bridge
/// @notice Stub for testnet genesis.
contract L2ERC721Bridge {
    address public messenger;
    address public otherBridge;

    function version() public pure returns (string memory) { return "1.8.0"; }
}

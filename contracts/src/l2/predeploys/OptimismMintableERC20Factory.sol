// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000012
/// @title OptimismMintableERC20Factory
/// @notice Factory for creating OptimismMintableERC20 tokens on L2.
///         Stub for testnet genesis.
contract OptimismMintableERC20Factory {
    address public bridge;

    event OptimismMintableERC20Created(address indexed localToken, address indexed remoteToken, address deployer);

    function version() public pure returns (string memory) { return "1.10.0"; }
}

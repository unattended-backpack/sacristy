// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000017
/// @title OptimismMintableERC721Factory
/// @notice Factory for creating OptimismMintableERC721 tokens on L2.
///         Stub for testnet genesis.
contract OptimismMintableERC721Factory {
    address public bridge;
    uint256 public remoteChainId;

    event OptimismMintableERC721Created(address indexed localToken, address indexed remoteToken, address deployer);

    function version() public pure returns (string memory) { return "1.5.0"; }
}

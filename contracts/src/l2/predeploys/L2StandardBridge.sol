// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000010
/// @title L2StandardBridge
/// @notice The L2 side of the standard bridge for moving tokens between L1 and L2.
///         Stub for testnet genesis.
contract L2StandardBridge {
    address public l1TokenBridge;
    address public messenger;

    event WithdrawalInitiated(
        address indexed l1Token, address indexed l2Token, address indexed from,
        address to, uint256 amount, bytes extraData
    );
    event DepositFinalized(
        address indexed l1Token, address indexed l2Token, address indexed from,
        address to, uint256 amount, bytes extraData
    );

    function version() public pure returns (string memory) { return "1.11.0"; }

    receive() external payable {}
}

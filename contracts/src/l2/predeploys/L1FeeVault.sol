// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x420000000000000000000000000000000000001a
/// @title L1FeeVault
/// @notice The L1FeeVault accumulates the L1 portion of the transaction fees.
contract L1FeeVault {
    address public l1FeeWallet;
    uint256 public totalProcessed;

    event Withdrawal(uint256 value, address to, address from);

    function version() public pure returns (string memory) { return "1.5.0"; }

    receive() external payable {}
}

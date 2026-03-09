// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000019
/// @title BaseFeeVault
/// @notice The BaseFeeVault accumulates the base fee that is paid by transactions.
contract BaseFeeVault {
    address public l1FeeWallet;
    uint256 public totalProcessed;

    event Withdrawal(uint256 value, address to, address from);

    function version() public pure returns (string memory) { return "1.5.0"; }

    receive() external payable {}
}

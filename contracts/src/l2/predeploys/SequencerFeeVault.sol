// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000011
/// @title SequencerFeeVault
/// @notice The SequencerFeeVault accumulates any transaction priority fee revenue.
contract SequencerFeeVault {
    /// @notice Minimum balance before withdrawal is allowed.
    uint256 public constant MIN_WITHDRAWAL_AMOUNT = 10 ether;

    /// @notice Wallet that will receive the fees on L1.
    address public l1FeeWallet;

    /// @notice Total amount of fees withdrawn.
    uint256 public totalProcessed;

    event Withdrawal(uint256 value, address to, address from);

    function version() public pure returns (string memory) { return "1.5.0"; }

    receive() external payable {}
}

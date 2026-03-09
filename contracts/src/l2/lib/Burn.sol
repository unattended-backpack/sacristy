// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title Burn
/// @notice Utilities for burning stuff.
library Burn {
    /// @notice Burns a given amount of ETH.
    function eth(uint256 _amount) internal {
        new Burner{ value: _amount }();
    }
}

/// @title Burner
/// @notice Burner self-destructs on creation and sends all ETH to itself.
contract Burner {
    constructor() payable {
        selfdestruct(payable(address(this)));
    }
}

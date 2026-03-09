// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x420000000000000000000000000000000000000F
/// @title GasPriceOracle
/// @notice This contract maintains the variables responsible for computing the L1 portion of the
///         total fee charged on L2. The values are set by the L1Block predeploy.
///         This is a simplified version for testnet deployment.
contract GasPriceOracle {
    /// @notice L1Block predeploy address.
    address internal constant L1_BLOCK = 0x4200000000000000000000000000000000000015;

    /// @notice Indicates whether the Ecotone upgrade is active.
    bool public isEcotone;

    /// @notice Indicates whether the Fjord upgrade is active.
    bool public isFjord;

    function version() public pure returns (string memory) {
        return "1.4.0";
    }

    /// @notice Computes the L1 portion of the fee based on unsigned serialized transaction and
    ///         current L1 fee parameters.
    function getL1Fee(bytes memory _data) external view returns (uint256) {
        // Simplified: return 0 for testnet. Production would compute based on L1Block data.
        return 0;
    }

    /// @notice Set the Ecotone flag. Only callable by the depositor account.
    function setEcotone() external {
        require(msg.sender == 0xDeaDDEaDDeAdDeAdDEAdDEaddeAddEAdDEAd0001, "GasPriceOracle: not depositor");
        isEcotone = true;
    }

    /// @notice Set the Fjord flag.
    function setFjord() external {
        require(msg.sender == 0xDeaDDEaDDeAdDeAdDEAdDEaddeAddEAdDEAd0001, "GasPriceOracle: not depositor");
        isFjord = true;
    }

    /// @notice Retrieves the current gas price (L2 base fee).
    function gasPrice() public view returns (uint256) {
        return block.basefee;
    }

    /// @notice Retrieves the current L1 base fee from the L1Block predeploy.
    function l1BaseFee() public view returns (uint256 fee_) {
        // Read from L1Block.basefee() - slot 2
        assembly {
            // basefee is at storage slot 2 of L1Block (after number+timestamp packed in slot 0)
            let ptr := mload(0x40)
            mstore(ptr, 0x5cf2496900000000000000000000000000000000000000000000000000000000) // basefee()
            let success := staticcall(gas(), 0x4200000000000000000000000000000000000015, ptr, 4, ptr, 32)
            if success { fee_ := mload(ptr) }
        }
    }

    /// @notice Retrieves the current blob base fee from the L1Block predeploy.
    function blobBaseFee() public view returns (uint256 fee_) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0xf8206140) // blobBaseFee()
            let success := staticcall(gas(), 0x4200000000000000000000000000000000000015, ptr, 4, ptr, 32)
            if success { fee_ := mload(ptr) }
        }
    }
}

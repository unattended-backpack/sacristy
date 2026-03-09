// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Constants } from "src/l2/lib/Constants.sol";

/// @custom:predeploy 0x4200000000000000000000000000000000000015
/// @title L1Block
/// @notice The L1Block predeploy gives users access to information about the last known L1 block.
///         Values within this contract are updated once per epoch (every L1 block) and can only be
///         set by the "depositor" account, a special system address.
contract L1Block {
    /// @notice Address of the special depositor account.
    function DEPOSITOR_ACCOUNT() public pure returns (address addr_) {
        addr_ = Constants.DEPOSITOR_ACCOUNT;
    }

    /// @notice The latest L1 block number known by the L2 system.
    uint64 public number;

    /// @notice The latest L1 timestamp known by the L2 system.
    uint64 public timestamp;

    /// @notice The latest L1 base fee.
    uint256 public basefee;

    /// @notice The latest L1 blockhash.
    bytes32 public hash;

    /// @notice The number of L2 blocks in the same epoch.
    uint64 public sequenceNumber;

    /// @notice The scalar value applied to the L1 blob base fee portion of the blob-capable L1 cost func.
    uint32 public blobBaseFeeScalar;

    /// @notice The scalar value applied to the L1 base fee portion of the blob-capable L1 cost func.
    uint32 public baseFeeScalar;

    /// @notice The versioned hash to authenticate the batcher by.
    bytes32 public batcherHash;

    /// @notice The overhead value applied to the L1 portion of the transaction fee.
    /// @custom:legacy
    uint256 public l1FeeOverhead;

    /// @notice The scalar value applied to the L1 portion of the transaction fee.
    /// @custom:legacy
    uint256 public l1FeeScalar;

    /// @notice The latest L1 blob base fee.
    uint256 public blobBaseFee;

    /// @notice The constant value applied to the operator fee.
    uint64 public operatorFeeConstant;

    /// @notice The scalar value applied to the operator fee.
    uint32 public operatorFeeScalar;

    /// @notice The DA footprint gas scalar.
    uint16 public daFootprintGasScalar;

    /// @notice Semantic version.
    function version() public pure virtual returns (string memory) {
        return "1.8.0";
    }

    /// @notice Returns the gas paying token.
    function gasPayingToken() public pure virtual returns (address addr_, uint8 decimals_) {
        addr_ = Constants.ETHER;
        decimals_ = 18;
    }

    /// @notice Returns the gas paying token name.
    function gasPayingTokenName() public view virtual returns (string memory name_) {
        name_ = "Ether";
    }

    /// @notice Returns the gas paying token symbol.
    function gasPayingTokenSymbol() public view virtual returns (string memory symbol_) {
        symbol_ = "ETH";
    }

    /// @notice Returns false (not using custom gas token).
    function isCustomGasToken() public view virtual returns (bool is_) {
        is_ = false;
    }

    /// @custom:legacy
    /// @notice Updates the L1 block values.
    function setL1BlockValues(
        uint64 _number, uint64 _timestamp, uint256 _basefee, bytes32 _hash,
        uint64 _sequenceNumber, bytes32 _batcherHash, uint256 _l1FeeOverhead, uint256 _l1FeeScalar
    ) external {
        require(msg.sender == DEPOSITOR_ACCOUNT(), "L1Block: only the depositor account can set L1 block values");
        number = _number;
        timestamp = _timestamp;
        basefee = _basefee;
        hash = _hash;
        sequenceNumber = _sequenceNumber;
        batcherHash = _batcherHash;
        l1FeeOverhead = _l1FeeOverhead;
        l1FeeScalar = _l1FeeScalar;
    }

    /// @notice Updates the L1 block values for an Ecotone upgraded chain.
    /// Params are packed and passed in as raw msg.data instead of ABI to reduce calldata size.
    function setL1BlockValuesEcotone() public {
        address depositor = DEPOSITOR_ACCOUNT();
        assembly {
            if xor(caller(), depositor) {
                mstore(0x00, 0x3cc50b45)
                revert(0x1C, 0x04)
            }
            sstore(sequenceNumber.slot, shr(128, calldataload(4)))
            sstore(number.slot, shr(128, calldataload(20)))
            sstore(basefee.slot, calldataload(36))
            sstore(blobBaseFee.slot, calldataload(68))
            sstore(hash.slot, calldataload(100))
            sstore(batcherHash.slot, calldataload(132))
        }
    }

    /// @notice Updates the L1 block values for an Isthmus upgraded chain.
    function setL1BlockValuesIsthmus() public {
        setL1BlockValuesEcotone();
        assembly {
            sstore(operatorFeeConstant.slot, shr(160, calldataload(164)))
        }
    }

    /// @notice Updates the L1 block values for a Jovian upgraded chain.
    function setL1BlockValuesJovian() public {
        setL1BlockValuesEcotone();
        assembly {
            let opFeeParams := shr(160, calldataload(164))
            let daScalar := shr(240, calldataload(176))
            let slotVal := or(shl(96, daScalar), opFeeParams)
            sstore(operatorFeeConstant.slot, slotVal)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Types
/// @notice Contains various types used throughout the Optimism contract system.
library Types {
    /// @notice Struct representing the elements that are hashed together to generate an output root
    ///         which itself represents a snapshot of the L2 state.
    struct OutputRootProof {
        bytes32 version;
        bytes32 stateRoot;
        bytes32 messagePasserStorageRoot;
        bytes32 latestBlockhash;
    }

    /// @notice Struct representing a deposit transaction (L1 => L2 transaction).
    struct UserDepositTransaction {
        address from;
        address to;
        bool isCreation;
        uint256 value;
        uint256 mint;
        uint64 gasLimit;
        bytes data;
        bytes32 l1BlockHash;
        uint256 logIndex;
    }

    /// @notice Struct representing a withdrawal transaction.
    struct WithdrawalTransaction {
        uint256 nonce;
        address sender;
        address target;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    /// @notice Enum representing where the FeeVault withdraws funds to.
    enum WithdrawalNetwork {
        L1,
        L2
    }
}

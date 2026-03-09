// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Types } from "src/l2/lib/Types.sol";
import { Encoding } from "src/l2/lib/Encoding.sol";

/// @title Hashing
/// @notice Hashing handles Optimism's various different hashing schemes.
library Hashing {
    /// @notice Computes the hash of the RLP encoded L2 transaction for a deposit.
    function hashDepositTransaction(Types.UserDepositTransaction memory _tx)
        internal pure returns (bytes32)
    {
        return keccak256(Encoding.encodeDepositTransaction(_tx));
    }

    /// @notice Computes the deposit transaction's "source hash".
    function hashDepositSource(bytes32 _l1BlockHash, uint256 _logIndex)
        internal pure returns (bytes32)
    {
        bytes32 depositId = keccak256(abi.encode(_l1BlockHash, _logIndex));
        return keccak256(abi.encode(bytes32(0), depositId));
    }

    /// @notice Hashes the cross domain message based on the version encoded in the nonce.
    function hashCrossDomainMessage(
        uint256 _nonce, address _sender, address _target,
        uint256 _value, uint256 _gasLimit, bytes memory _data
    ) internal pure returns (bytes32) {
        (, uint16 version) = Encoding.decodeVersionedNonce(_nonce);
        if (version == 0) {
            return hashCrossDomainMessageV0(_target, _sender, _data, _nonce);
        } else if (version == 1) {
            return hashCrossDomainMessageV1(_nonce, _sender, _target, _value, _gasLimit, _data);
        } else {
            revert("Hashing: unknown cross domain message version");
        }
    }

    function hashCrossDomainMessageV0(
        address _target, address _sender, bytes memory _data, uint256 _nonce
    ) internal pure returns (bytes32) {
        return keccak256(Encoding.encodeCrossDomainMessageV0(_target, _sender, _data, _nonce));
    }

    function hashCrossDomainMessageV1(
        uint256 _nonce, address _sender, address _target,
        uint256 _value, uint256 _gasLimit, bytes memory _data
    ) internal pure returns (bytes32) {
        return keccak256(Encoding.encodeCrossDomainMessageV1(_nonce, _sender, _target, _value, _gasLimit, _data));
    }

    /// @notice Derives the withdrawal hash.
    function hashWithdrawal(Types.WithdrawalTransaction memory _tx)
        internal pure returns (bytes32)
    {
        return keccak256(abi.encode(_tx.nonce, _tx.sender, _tx.target, _tx.value, _tx.gasLimit, _tx.data));
    }

    /// @notice Hashes an output root proof into an output root hash.
    function hashOutputRootProof(Types.OutputRootProof memory _outputRootProof)
        internal pure returns (bytes32)
    {
        return keccak256(abi.encode(
            _outputRootProof.version,
            _outputRootProof.stateRoot,
            _outputRootProof.messagePasserStorageRoot,
            _outputRootProof.latestBlockhash
        ));
    }
}

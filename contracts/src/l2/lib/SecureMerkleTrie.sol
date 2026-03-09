// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { MerkleTrie } from "src/l2/lib/MerkleTrie.sol";

/// @title SecureMerkleTrie
/// @notice Thin wrapper around MerkleTrie that hashes input keys (Ethereum state trie pattern).
library SecureMerkleTrie {
    function verifyInclusionProof(
        bytes memory _key, bytes memory _value, bytes[] memory _proof, bytes32 _root
    ) internal pure returns (bool valid_) {
        bytes memory key = _getSecureKey(_key);
        valid_ = MerkleTrie.verifyInclusionProof(key, _value, _proof, _root);
    }

    function get(bytes memory _key, bytes[] memory _proof, bytes32 _root)
        internal pure returns (bytes memory value_)
    {
        bytes memory key = _getSecureKey(_key);
        value_ = MerkleTrie.get(key, _proof, _root);
    }

    function _getSecureKey(bytes memory _key) private pure returns (bytes memory hash_) {
        hash_ = abi.encodePacked(keccak256(_key));
    }
}

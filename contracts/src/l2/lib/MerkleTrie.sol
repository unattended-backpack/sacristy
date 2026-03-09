// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Bytes } from "src/l2/lib/Bytes.sol";
import { RLPReader } from "src/l2/lib/RLPReader.sol";

/// @title MerkleTrie
/// @notice MerkleTrie is a library for verifying standard Ethereum Merkle-Patricia trie
///         inclusion proofs.
library MerkleTrie {
    struct TrieNode {
        bytes encoded;
        RLPReader.RLPItem[] decoded;
    }

    uint256 internal constant TREE_RADIX = 16;
    uint256 internal constant BRANCH_NODE_LENGTH = TREE_RADIX + 1;
    uint256 internal constant LEAF_OR_EXTENSION_NODE_LENGTH = 2;
    uint8 internal constant PREFIX_EXTENSION_EVEN = 0;
    uint8 internal constant PREFIX_EXTENSION_ODD = 1;
    uint8 internal constant PREFIX_LEAF_EVEN = 2;
    uint8 internal constant PREFIX_LEAF_ODD = 3;

    function verifyInclusionProof(
        bytes memory _key, bytes memory _value, bytes[] memory _proof, bytes32 _root
    ) internal pure returns (bool valid_) {
        valid_ = Bytes.equal(_value, get(_key, _proof, _root));
    }

    function get(bytes memory _key, bytes[] memory _proof, bytes32 _root)
        internal pure returns (bytes memory value_)
    {
        require(_key.length > 0, "MerkleTrie: empty key");
        TrieNode[] memory proof = _parseProof(_proof);
        bytes memory key = Bytes.toNibbles(_key);
        bytes memory currentNodeID = abi.encodePacked(_root);
        uint256 currentKeyIndex = 0;

        for (uint256 i = 0; i < proof.length; i++) {
            TrieNode memory currentNode = proof[i];
            require(currentKeyIndex <= key.length, "MerkleTrie: key index exceeds total key length");

            if (currentKeyIndex == 0) {
                require(
                    Bytes.equal(abi.encodePacked(keccak256(currentNode.encoded)), currentNodeID),
                    "MerkleTrie: invalid root hash"
                );
            } else if (currentNode.encoded.length >= 32) {
                require(
                    Bytes.equal(abi.encodePacked(keccak256(currentNode.encoded)), currentNodeID),
                    "MerkleTrie: invalid large internal hash"
                );
            } else {
                require(Bytes.equal(currentNode.encoded, currentNodeID), "MerkleTrie: invalid internal node hash");
            }

            if (currentNode.decoded.length == BRANCH_NODE_LENGTH) {
                if (currentKeyIndex == key.length) {
                    value_ = RLPReader.readBytes(currentNode.decoded[TREE_RADIX]);
                    require(value_.length > 0, "MerkleTrie: value length must be greater than zero (branch)");
                    require(i == proof.length - 1, "MerkleTrie: value node must be last node in proof (branch)");
                    return value_;
                } else {
                    uint8 branchKey = uint8(key[currentKeyIndex]);
                    RLPReader.RLPItem memory nextNode = currentNode.decoded[branchKey];
                    currentNodeID = _getNodeID(nextNode);
                    currentKeyIndex += 1;
                }
            } else if (currentNode.decoded.length == LEAF_OR_EXTENSION_NODE_LENGTH) {
                bytes memory path = _getNodePath(currentNode);
                uint8 prefix = uint8(path[0]);
                uint8 offset = 2 - (prefix % 2);
                bytes memory pathRemainder = Bytes.slice(path, offset);
                bytes memory keyRemainder = Bytes.slice(key, currentKeyIndex);
                uint256 sharedNibbleLength = _getSharedNibbleLength(pathRemainder, keyRemainder);

                require(
                    pathRemainder.length == sharedNibbleLength,
                    "MerkleTrie: path remainder must share all nibbles with key"
                );

                if (prefix == PREFIX_LEAF_EVEN || prefix == PREFIX_LEAF_ODD) {
                    require(
                        keyRemainder.length == sharedNibbleLength,
                        "MerkleTrie: key remainder must be identical to path remainder"
                    );
                    value_ = RLPReader.readBytes(currentNode.decoded[1]);
                    require(value_.length > 0, "MerkleTrie: value length must be greater than zero (leaf)");
                    require(i == proof.length - 1, "MerkleTrie: value node must be last node in proof (leaf)");
                    return value_;
                } else if (prefix == PREFIX_EXTENSION_EVEN || prefix == PREFIX_EXTENSION_ODD) {
                    currentNodeID = _getNodeID(currentNode.decoded[1]);
                    currentKeyIndex += sharedNibbleLength;
                } else {
                    revert("MerkleTrie: received a node with an unknown prefix");
                }
            } else {
                revert("MerkleTrie: received an unparseable node");
            }
        }
        revert("MerkleTrie: ran out of proof elements");
    }

    function _parseProof(bytes[] memory _proof) private pure returns (TrieNode[] memory proof_) {
        uint256 length = _proof.length;
        proof_ = new TrieNode[](length);
        for (uint256 i = 0; i < length;) {
            proof_[i] = TrieNode({ encoded: _proof[i], decoded: RLPReader.readList(_proof[i]) });
            unchecked { ++i; }
        }
    }

    function _getNodeID(RLPReader.RLPItem memory _node) private pure returns (bytes memory id_) {
        id_ = _node.length < 32 ? RLPReader.readRawBytes(_node) : RLPReader.readBytes(_node);
    }

    function _getNodePath(TrieNode memory _node) private pure returns (bytes memory nibbles_) {
        nibbles_ = Bytes.toNibbles(RLPReader.readBytes(_node.decoded[0]));
    }

    function _getSharedNibbleLength(bytes memory _a, bytes memory _b) private pure returns (uint256 shared_) {
        uint256 max = (_a.length < _b.length) ? _a.length : _b.length;
        for (; shared_ < max && _a[shared_] == _b[shared_];) {
            unchecked { ++shared_; }
        }
    }
}

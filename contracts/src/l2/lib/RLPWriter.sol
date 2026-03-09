// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title RLPWriter
/// @notice RLPWriter is a library for encoding Solidity types to RLP bytes.
library RLPWriter {
    function writeBytes(bytes memory _in) internal pure returns (bytes memory out_) {
        if (_in.length == 1 && uint8(_in[0]) < 128) {
            out_ = _in;
        } else {
            out_ = abi.encodePacked(_writeLength(_in.length, 128), _in);
        }
    }

    function writeList(bytes[] memory _in) internal pure returns (bytes memory list_) {
        list_ = _flatten(_in);
        list_ = abi.encodePacked(_writeLength(list_.length, 192), list_);
    }

    function writeString(string memory _in) internal pure returns (bytes memory out_) {
        out_ = writeBytes(bytes(_in));
    }

    function writeAddress(address _in) internal pure returns (bytes memory out_) {
        out_ = writeBytes(abi.encodePacked(_in));
    }

    function writeUint(uint256 _in) internal pure returns (bytes memory out_) {
        out_ = writeBytes(_toBinary(_in));
    }

    function writeBool(bool _in) internal pure returns (bytes memory out_) {
        out_ = new bytes(1);
        out_[0] = (_in ? bytes1(0x01) : bytes1(0x80));
    }

    function _writeLength(uint256 _len, uint256 _offset) private pure returns (bytes memory out_) {
        if (_len < 56) {
            out_ = new bytes(1);
            out_[0] = bytes1(uint8(_len) + uint8(_offset));
        } else {
            uint256 lenLen;
            uint256 i = 1;
            while (_len / i != 0) {
                lenLen++;
                i *= 256;
            }
            out_ = new bytes(lenLen + 1);
            out_[0] = bytes1(uint8(lenLen) + uint8(_offset) + 55);
            for (i = 1; i <= lenLen; i++) {
                out_[i] = bytes1(uint8((_len / (256 ** (lenLen - i))) % 256));
            }
        }
    }

    function _toBinary(uint256 _x) private pure returns (bytes memory out_) {
        bytes memory b = abi.encodePacked(_x);
        uint256 i = 0;
        for (; i < 32; i++) {
            if (b[i] != 0) break;
        }
        out_ = new bytes(32 - i);
        for (uint256 j = 0; j < out_.length; j++) {
            out_[j] = b[i++];
        }
    }

    function _memcpy(uint256 _dest, uint256 _src, uint256 _len) private pure {
        uint256 dest = _dest;
        uint256 src = _src;
        uint256 len = _len;
        for (; len >= 32; len -= 32) {
            assembly { mstore(dest, mload(src)) }
            dest += 32;
            src += 32;
        }
        uint256 mask;
        unchecked { mask = 256 ** (32 - len) - 1; }
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    function _flatten(bytes[] memory _list) private pure returns (bytes memory out_) {
        if (_list.length == 0) return new bytes(0);
        uint256 len;
        uint256 i = 0;
        for (; i < _list.length; i++) { len += _list[i].length; }
        out_ = new bytes(len);
        uint256 flattenedPtr;
        assembly { flattenedPtr := add(out_, 0x20) }
        for (i = 0; i < _list.length; i++) {
            bytes memory item = _list[i];
            uint256 listPtr;
            assembly { listPtr := add(item, 0x20) }
            _memcpy(flattenedPtr, listPtr, item.length);
            flattenedPtr += _list[i].length;
        }
    }
}

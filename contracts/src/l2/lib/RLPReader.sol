// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {
    EmptyItem, UnexpectedString, InvalidDataRemainder,
    ContentLengthMismatch, InvalidHeader, UnexpectedList
} from "src/l2/lib/RLPErrors.sol";

/// @title RLPReader
/// @notice RLPReader is a library for parsing RLP-encoded byte arrays into Solidity types.
library RLPReader {
    type MemoryPointer is uint256;

    enum RLPItemType { DATA_ITEM, LIST_ITEM }

    struct RLPItem {
        uint256 length;
        MemoryPointer ptr;
    }

    uint256 internal constant MAX_LIST_LENGTH = 32;

    function toRLPItem(bytes memory _in) internal pure returns (RLPItem memory out_) {
        if (_in.length == 0) revert EmptyItem();
        MemoryPointer ptr;
        assembly { ptr := add(_in, 32) }
        out_ = RLPItem({ length: _in.length, ptr: ptr });
    }

    function readList(RLPItem memory _in) internal pure returns (RLPItem[] memory out_) {
        (uint256 listOffset, uint256 listLength, RLPItemType itemType) = _decodeLength(_in);
        if (itemType != RLPItemType.LIST_ITEM) revert UnexpectedString();
        if (listOffset + listLength != _in.length) revert InvalidDataRemainder();
        out_ = new RLPItem[](MAX_LIST_LENGTH);
        uint256 itemCount = 0;
        uint256 offset = listOffset;
        while (offset < _in.length) {
            (uint256 itemOffset, uint256 itemLength,) = _decodeLength(
                RLPItem({ length: _in.length - offset, ptr: MemoryPointer.wrap(MemoryPointer.unwrap(_in.ptr) + offset) })
            );
            out_[itemCount] = RLPItem({
                length: itemLength + itemOffset,
                ptr: MemoryPointer.wrap(MemoryPointer.unwrap(_in.ptr) + offset)
            });
            itemCount += 1;
            offset += itemOffset + itemLength;
        }
        assembly { mstore(out_, itemCount) }
    }

    function readList(bytes memory _in) internal pure returns (RLPItem[] memory out_) {
        out_ = readList(toRLPItem(_in));
    }

    function readBytes(RLPItem memory _in) internal pure returns (bytes memory out_) {
        (uint256 itemOffset, uint256 itemLength, RLPItemType itemType) = _decodeLength(_in);
        if (itemType != RLPItemType.DATA_ITEM) revert UnexpectedList();
        if (_in.length != itemOffset + itemLength) revert InvalidDataRemainder();
        out_ = _copy(_in.ptr, itemOffset, itemLength);
    }

    function readBytes(bytes memory _in) internal pure returns (bytes memory out_) {
        out_ = readBytes(toRLPItem(_in));
    }

    function readRawBytes(RLPItem memory _in) internal pure returns (bytes memory out_) {
        out_ = _copy(_in.ptr, 0, _in.length);
    }

    function _decodeLength(RLPItem memory _in)
        private pure returns (uint256 offset_, uint256 length_, RLPItemType type_)
    {
        if (_in.length == 0) revert EmptyItem();
        MemoryPointer ptr = _in.ptr;
        uint256 prefix;
        assembly { prefix := byte(0, mload(ptr)) }
        if (prefix <= 0x7f) {
            return (0, 1, RLPItemType.DATA_ITEM);
        } else if (prefix <= 0xb7) {
            uint256 strLen = prefix - 0x80;
            if (_in.length <= strLen) revert ContentLengthMismatch();
            bytes1 firstByteOfContent;
            assembly { firstByteOfContent := and(mload(add(ptr, 1)), shl(248, 0xff)) }
            if (strLen == 1 && firstByteOfContent < 0x80) revert InvalidHeader();
            return (1, strLen, RLPItemType.DATA_ITEM);
        } else if (prefix <= 0xbf) {
            uint256 lenOfStrLen = prefix - 0xb7;
            if (_in.length <= lenOfStrLen) revert ContentLengthMismatch();
            bytes1 firstByteOfContent;
            assembly { firstByteOfContent := and(mload(add(ptr, 1)), shl(248, 0xff)) }
            if (firstByteOfContent == 0x00) revert InvalidHeader();
            uint256 strLen;
            assembly { strLen := shr(sub(256, mul(8, lenOfStrLen)), mload(add(ptr, 1))) }
            if (strLen <= 55) revert InvalidHeader();
            if (_in.length <= lenOfStrLen + strLen) revert ContentLengthMismatch();
            return (1 + lenOfStrLen, strLen, RLPItemType.DATA_ITEM);
        } else if (prefix <= 0xf7) {
            uint256 listLen = prefix - 0xc0;
            if (_in.length <= listLen) revert ContentLengthMismatch();
            return (1, listLen, RLPItemType.LIST_ITEM);
        } else {
            uint256 lenOfListLen = prefix - 0xf7;
            if (_in.length <= lenOfListLen) revert ContentLengthMismatch();
            bytes1 firstByteOfContent;
            assembly { firstByteOfContent := and(mload(add(ptr, 1)), shl(248, 0xff)) }
            if (firstByteOfContent == 0x00) revert InvalidHeader();
            uint256 listLen;
            assembly { listLen := shr(sub(256, mul(8, lenOfListLen)), mload(add(ptr, 1))) }
            if (listLen <= 55) revert InvalidHeader();
            if (_in.length <= lenOfListLen + listLen) revert ContentLengthMismatch();
            return (1 + lenOfListLen, listLen, RLPItemType.LIST_ITEM);
        }
    }

    function _copy(MemoryPointer _src, uint256 _offset, uint256 _length) private pure returns (bytes memory out_) {
        out_ = new bytes(_length);
        if (_length == 0) return out_;
        uint256 src = MemoryPointer.unwrap(_src) + _offset;
        assembly {
            let dest := add(out_, 32)
            let i := 0
            for { } lt(i, _length) { i := add(i, 32) } { mstore(add(dest, i), mload(add(src, i))) }
            if gt(i, _length) { mstore(add(dest, _length), 0) }
        }
    }
}

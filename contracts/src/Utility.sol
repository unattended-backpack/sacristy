// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Utility
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  Shared utility functions for scripts and contracts.

  @custom:date December 23rd, 2025.
*/
library Utility {

  /**
    Convert an address to a lowercase hex string without the 0x prefix.

    @param _address The address to convert.

    @return _ The lowercase hex string representation.
  */
  function addressToString (
    address _address
  ) internal pure returns (string memory) {
    bytes memory _alphabet = "0123456789abcdef";
    bytes20 _value = bytes20(_address);
    bytes memory _str = new bytes(40);
    for (uint256 i = 0; i < 20; i++) {
      _str[i * 2] = _alphabet[uint8(_value[i] >> 4)];
      _str[i * 2 + 1] = _alphabet[uint8(_value[i] & 0x0f)];
    }
    return string(_str);
  }

  /**
    Split a string upon a delimiter into an array.

    @param _input The string to split.
    @param _delimiter The delimiting character to split upon.

    @return _ The array of split strings.
  */
  function splitString (
    string memory _input,
    bytes1 _delimiter
  ) internal pure returns (string[] memory) {
    bytes memory _inputBytes = bytes(_input);
    if (_inputBytes.length == 0) {
      return new string[](0);
    }

    // Count delimiters to determine array size.
    uint256 _count = 1;
    for (uint256 i = 0; i < _inputBytes.length; i++) {
      if (_inputBytes[i] == _delimiter) {
        _count++;
      }
    }

    // Build the result.
    string[] memory _result = new string[](_count);
    uint256 _start = 0;
    uint256 _idx = 0;
    for (uint256 i = 0; i <= _inputBytes.length; i++) {
      if (i == _inputBytes.length || _inputBytes[i] == _delimiter) {
        uint256 _len = i - _start;
        bytes memory _part = new bytes(_len);
        for (uint256 j = 0; j < _len; j++) {
          _part[j] = _inputBytes[_start + j];
        }
        _result[_idx] = string(_part);
        _idx++;
        _start = i + 1;
      }
    }
    return _result;
  }
}


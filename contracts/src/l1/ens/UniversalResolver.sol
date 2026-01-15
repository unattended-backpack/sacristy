// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { IENSRegistry } from "./interfaces/IENSRegistry.sol";
import { IPublicResolver } from "./interfaces/IPublicResolver.sol";
import { IUniversalResolver } from "./interfaces/IUniversalResolver.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Minimal Universal Resolver
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A simplified ENS universal resolver supporting address and name resolution.

  @custom:date January 15th, 2026.
*/
contract UniversalResolver is
  IUniversalResolver {

  /// The hardcoded ENS registry address (same as PublicResolver).
  IENSRegistry public constant ENS =
    IENSRegistry(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

  /// The hardcoded public resolver address.
  IPublicResolver public constant RESOLVER =
    IPublicResolver(0xF29100983E058B709F3D539b0c765937B804AC15);

  /// The namehash of the `addr.reverse` node.
  bytes32 private constant ADDR_REVERSE_NODE =
    0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

  /**
    Compute namehash from DNS-encoded name starting at a given offset.

    @param _name The DNS-encoded name.
    @param _offset The offset to start from.

    @return _ The namehash.
  */
  function _namehashFromDns (
    bytes memory _name,
    uint256 _offset
  ) private pure returns (bytes32) {
    if (_offset >= _name.length || _name[_offset] == 0) {
      return bytes32(0);
    }
    uint256 _labelLength = uint256(uint8(_name[_offset]));
    bytes32 _labelHash;
    assembly {
      _labelHash := keccak256(add(add(_name, 33), _offset), _labelLength)
    }
    bytes32 _parentHash = _namehashFromDns(_name, _offset + _labelLength + 1);
    return keccak256(abi.encodePacked(_parentHash, _labelHash));
  }

  /**
    Convert a dot-separated name to DNS-encoded format.

    @param _name The dot-separated name (e.g., "test.eth").

    @return _ _result The DNS-encoded name.
  */
  function _nameToDns (
    string memory _name
  ) private pure returns (bytes memory) {
    bytes memory _nameBytes = bytes(_name);
    if (_nameBytes.length == 0) {
      return hex"00";
    }

    // Count labels to allocate result.
    bytes memory _result = new bytes(_nameBytes.length + 2);
    uint256 _resultIndex = 0;
    uint256 _labelStart = 0;

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    for (uint256 i = 0; i <= _nameBytes.length; i++) {
      if (i == _nameBytes.length || _nameBytes[i] == ".") {
        uint256 _labelLength = i - _labelStart;
        _result[_resultIndex++] = bytes1(uint8(_labelLength));
        for (uint256 j = _labelStart; j < i; j++) {
          _result[_resultIndex++] = _nameBytes[j];
        }
        _labelStart = i + 1;
      }
    }
    _result[_resultIndex] = 0;
    assembly {
      mstore(_result, _resultIndex)
    }
    return _result;
  }

  /**
    Convert bytes to an address.

    @param _b The bytes to convert.

    @return _ The address.
  */
  function _bytesToAddress (
    bytes calldata _b
  ) private pure returns (address) {

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    if (_b.length == 20) {
      return address(bytes20(_b));
    }

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    if (_b.length == 32) {
      return address(uint160(uint256(bytes32(_b))));
    }
    return address(uint160(bytes20(_b[:20])));
  }

  /**
    Convert an address to lowercase hex bytes (without 0x prefix).

    @param _addr The address to convert.

    @return _ _result The lowercase hex string as bytes.
  */
  function _addressToHex (
    address _addr
  ) private pure returns (bytes memory) {
    bytes memory _result = new bytes(40);
    bytes memory _alphabet = "0123456789abcdef";

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    for (uint256 i = 0; i < 20; i++) {
      _result[i * 2] = _alphabet[uint8(uint160(_addr) >> (8 * (19 - i)) >> 4) &
      0xf];
      _result[i * 2 + 1] = _alphabet[uint8(uint160(_addr) >> (8 * (19 - i))) &
      0xf];
    }
    return _result;
  }

  /**
    Find the resolver address for `_name`.

    @param _name The name to search.

    @return _ A tuple consisting of (the address of the resolver, the namehash
      of `_name`, and the offset into `_name` corresponding to the resolver).
  */
  function findResolver (
    bytes memory _name
  ) public view returns (address, bytes32, uint256) {
    uint256 _offset = 0;
    bytes32 _namehash = _namehashFromDns(_name, 0);

    // Walk through the name hierarchy looking for a resolver.
    while (_offset < _name.length) {
      bytes32 _node = _namehashFromDns(_name, _offset);
      address _resolver = ENS.resolver(_node);

      // If this node has a resolver, return it.
      if (_resolver != address(0)) {
        if (_resolver.code.length == 0) {
          revert ResolverNotContract(_name, _resolver);
        }
        return (_resolver, _namehash, _offset);
      }

      // Move to the next label.
      uint256 _labelLength = uint256(uint8(_name[_offset]));
      if (_labelLength == 0) {
        break;
      }
      _offset += _labelLength + 1;
    }
    revert ResolverNotFound(_name);
  }

  /**
    Perform ENS name resolution for the supplied name and resolution data.

    @param _name The name to resolve in normalized DNS-encoded form.
    @param _data The name resolution data.

    @return _ A tuple consisting of (the name resolution result, and the address
      of the resolver used).
  */
  function resolve (
    bytes calldata _name,
    bytes calldata _data
  ) external view returns (bytes memory, address) {
    (address _resolver, , ) = findResolver(_name);
    (bool _success, bytes memory _result) = _resolver.staticcall(_data);
    if (!_success) {
      if (_result.length == 0) {
        revert UnsupportedResolverProfile(bytes4(_data[:4]));
      }
      revert ResolverError(_result);
    }
    return (_result, _resolver);
  }

  /**
    Perform ENS reverse resolution for the supplied `_address` and `_coinType`.

    @param _address The address to reverse resolve, in encoded form.
    @param _coinType THe coin type to use for the reverse resolution. For
      Ethereum, this is 60. For other EVM chains this is `0x80000000 | chainId`.

    @return _ A tuple consisting of (the reverse resolution result, the address
      of the resolver used to resolve the name, and the address of the resolver
      usued to resolve the reverse name).
  */
  function reverse (
    bytes calldata _address,
    uint256 _coinType
  ) external view returns (string memory, address, address) {

    // Build the reverse node: keccak256(ADDR_REVERSE_NODE, keccak256(hexaddr)).
    address _addr = _bytesToAddress(_address);
    bytes32 _reverseNode =
      keccak256(
        abi.encodePacked(ADDR_REVERSE_NODE, keccak256(_addressToHex(_addr)))
      );

    // Get the reverse resolver and look up the name.
    address _reverseResolver = ENS.resolver(_reverseNode);
    if (_reverseResolver == address(0)) {
      revert ResolverNotFound(_address);
    }
    string memory _name =
      IPublicResolver(_reverseResolver).names(_reverseNode);
    if (bytes(_name).length == 0) {
      revert ResolverNotFound(_address);
    }

    // Verify forward resolution matches (if coinType is Ethereum mainnet).
    bytes memory _dnsName = _nameToDns(_name);
    bytes32 _forwardNode = _namehashFromDns(_dnsName, 0);
    address _forwardResolver = ENS.resolver(_forwardNode);
    if (_forwardResolver == address(0)) {
      _forwardResolver = address(RESOLVER);
    }

    // For Ethereum (coinType 60), verify the address matches.
    if (_coinType == 60) {
      address _resolved =
        IPublicResolver(_forwardResolver).addresses(_forwardNode);
      if (_resolved != _addr) {
        revert ReverseAddressMismatch(_name, _address);
      }
    }
    return (_name, _forwardResolver, _reverseResolver);
  }
}


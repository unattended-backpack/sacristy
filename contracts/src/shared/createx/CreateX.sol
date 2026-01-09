// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { ICreateX } from "./interfaces/ICreateX.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title CreateX Factory
  @custom:blame Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"
  @custom:preserve

  This is a stylistically-modified version of CreateX, the phenomenal factory
  smart contract authored by `pcaversaccio`
  (https://web.archive.org/web/20230921103111/https://pcaversaccio.com/) and
  `Matt Solomon`
  (https://web.archive.org/web/20230921103335/https://mattsolomon.dev/). Do not
  blame or bother them, or upstream CreateX, regarding any issues you find with
  this contract. CreateX is an excellent option for safely creating smart
  contracts at predetermined addresses.

  @custom:date January 6th, 2026.
*/
contract CreateX is
  ICreateX {

  /**
    An event emitted when a contract is successfully created using `CREATE`.

    @param newContract The address of the new contract.
  */
  event ContractCreation (
    address indexed newContract
  );

  /**
    An event emitted when a contract is successfully created using `CREATE2`.

    @param newContract The address of the new contract.
    @param salt The salt used to create the contract.
  */
  event ContractCreation (
    address indexed newContract,
    bytes32 indexed salt
  );

  /**
    An event emitted when a `CREATE3` proxy contract is successfully created.

    @param newContract The address of the new proxy contract.
    @param salt The salt used to create the contract.
  */
  event Create3ProxyContractCreation (
    address indexed newContract,
    bytes32 indexed salt
  );

  /**
    Parse a given salt to decode settings for permissioned deployer protection
    and cross-chain redeploy protection.

    @param _salt The 32-byte value used to create the contract address.

    @return _ A tuple of (SenderBytes, RedeployProtectionFlag) containing the
      decoded protection parts of the `_salt`.
  */
  function _parseSalt (
    bytes32 _salt
  ) internal view returns (SenderBytes, RedeployProtectionFlag) {

    // The salt is protected to the caller with cross-chain use disallowed.
    // @custom:preserve
    // forge-lint: disable-next-line(unsafe-typecast)
    if (address(bytes20(_salt)) == msg.sender && bytes1(_salt[20]) == hex"01") {
      return (SenderBytes.MsgSender, RedeployProtectionFlag.True);

    // The salt is protected to the caller with cross-chain use allowed.
    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    } else if (
      address(bytes20(_salt)) == msg.sender && bytes1(_salt[20]) == hex"00"
    ) {
      return (SenderBytes.MsgSender, RedeployProtectionFlag.False);

    // The salt is protected to the caller with invalid cross-chain settings.
    // @custom:preserve
    // forge-lint: disable-next-line(unsafe-typecast)
    } else if (address(bytes20(_salt)) == msg.sender) {
      return (SenderBytes.MsgSender, RedeployProtectionFlag.Unspecified);

    // The salt is unprotected with cross-chain use disallowed.
    // @custom:preserve
    // forge-lint: disable-next-line(unsafe-typecast)
    } else if (
      address(bytes20(_salt)) == address(0) && bytes1(_salt[20]) == hex"01"
    ) {
      return (SenderBytes.ZeroAddress, RedeployProtectionFlag.True);

    // The salt is unprotected with cross-chain use allowed.
    // @custom:preserve
    // forge-lint: disable-next-line(unsafe-typecast)
    } else if (
      address(bytes20(_salt)) == address(0) && bytes1(_salt[20]) == hex"00"
    ) {
      return (SenderBytes.ZeroAddress, RedeployProtectionFlag.False);

    // The salt is unprotected with invalid cross-chain settings.
    // @custom:preserve
    // forge-lint: disable-next-line(unsafe-typecast)
    } else if (address(bytes20(_salt)) == address(0)) {
      return (SenderBytes.ZeroAddress, RedeployProtectionFlag.Unspecified);

    /*
      The salt is unprotected with more randomness than the zero address alone
      and cross-chain use disallowed.
    */
    } else if (bytes1(_salt[20]) == hex"01") {
      return (SenderBytes.Random, RedeployProtectionFlag.True);

    /*
      The sale is unprotected with more randomness than the zero address alone
      and cross-chain use is allowed.
    */
    } else if (bytes1(_salt[20]) == hex"00") {
      return (SenderBytes.Random, RedeployProtectionFlag.False);

    // The salt has invalid cross-chain settings.
    } else {
      return (SenderBytes.Random, RedeployProtectionFlag.Unspecified);
    }
  }

  /**
    Return the keccak256 hash of `_a` and `_b` after concatenation.

    @param _a The first 32-byte value to be concatenated and hashed.
    @param _b The second 32-byte value to be concatenated and hashed.

    @return _ The 32-byte keccak256 hash of `_a` and `_b`.
  */
  function _efficientHash (
    bytes32 _a,
    bytes32 _b
  ) internal pure returns (bytes32) {
    bytes32 _hashOutput;
    assembly ("memory-safe") {
      mstore(0x00, _a)
      mstore(0x20, _b)
      _hashOutput := keccak256(0x00, 0x40)
    }
    return _hashOutput;
  }

  /**
    Pseudorandomly generate a salt value using a diverse selection of block and
    transaction properties.

    @return _ The 32-byte pseudorandom salt value.
  */
  function _generateSalt () internal view returns (bytes32) {
    {
      return keccak256(
        abi.encode(
          blockhash(block.number - 32), block.coinbase, block.number,
          block.timestamp, block.prevrandao, block.chainid, msg.sender
        )
      );
    }
  }

  /**
    Implement different protection mechanisms depending on the encoded values in
    the salt. Let `||` stand for byte-wise concatenation: salt (32 bytes) =
    0xbebebebebebebebebebebebebebebebebebebebe||ff||1212121212121212121212. The
    first 20 bytes (i.e. `bebebebebebebebebebebebebebebebebebebebe`) may be used
    for permissioned deploy protection by setting them equal to `msg.sender`.
    The 21st byte (i.e. `ff`) may be used to implement cross-chain redeploy
    protection by setting it equal to `0x01`. The last random 11 bytes (i.e.
    `1212121212121212121212`) allow for 2**88 bits of entropy for mining a salt.

    @param _salt The 32-byte value used to create the contract address.

    @return _ The guarded 32-byte random value used to create the final contract
      address after accounting for deployment protections..
  */
  function _guard (
    bytes32 _salt
  ) internal view returns (bytes32) {
    (SenderBytes _senderBytes, RedeployProtectionFlag _redeployProtectionFlag)
     = _parseSalt(_salt);

    // Configure permissioned deploy and cross-chain redeploy protections.
    if (
      _senderBytes == SenderBytes.MsgSender
      && _redeployProtectionFlag == RedeployProtectionFlag.True
    ) {
      return keccak256(abi.encode(msg.sender, block.chainid, _salt));

    // Configure only permissioned deploy protection.
    } else if (
      _senderBytes == SenderBytes.MsgSender
      && _redeployProtectionFlag == RedeployProtectionFlag.False
    ) {
      return _efficientHash(bytes32(uint256(uint160(msg.sender))), _salt);

    // Reject an invalid salt.
    } else if (_senderBytes == SenderBytes.MsgSender) {
      revert InvalidSalt();

    /*
      Configure only cross-chain redeploy protection. The explicit check for the
      zero address is used to prevent accidentally mining unwanted cross-chain
      redeploy protection.
    */
    } else if (
      _senderBytes == SenderBytes.ZeroAddress
      && _redeployProtectionFlag == RedeployProtectionFlag.True
    ) {
      return _efficientHash(bytes32(block.chainid), _salt);

    // Reject an invalid salt.
    } else if (
      _senderBytes == SenderBytes.ZeroAddress
      && _redeployProtectionFlag == RedeployProtectionFlag.Unspecified
    ) {
      revert InvalidSalt();

    /*
      For the non-pseudo-random cases, the salt value `_salt` is hashed to
      prevent the safeguard mechanisms from being bypassed. Otherwise, the salt
      value `_salt` is not modified.
    */
    } else if (_salt != _generateSalt()) {
      return keccak256(abi.encode(_salt));
    } else {
      return _salt;
    }
  }

  /**
    Compute the address where a contract will be stored if deployed via
    `deployer` using the `CREATE` opcode. For the specification of the Recursive
    Length Prefix (RLP) encoding scheme, please refer to p. 19 of the Ethereum
    Yellow Paper and the Ethereum Wiki. All contract accounts on Ethereum are
    initiated with `nonce = 1`. Thus, the first contract address created by
    another contract is calculated with a non-zero nonce.

    @param _deployer The 20-byte deployer address.
    @param _nonce The next 32-byte nonce of the deployer address.

    @return _ The 20-byte address where a contract will be stored.
  */
  function computeCreateAddress (
    address _deployer,
    uint256 _nonce
  ) public pure returns (address) {
    bytes memory _data;
    bytes1 _len = bytes1(0x94);

    // The EIP-2681 limit for an account nonce is 2**64-2.
    if (_nonce > type(uint64).max - 1) {
      revert InvalidNonceValue();
    }

    /*
      The integer zero is treated as an empty byte string and therefore has only
      one length prefix, 0x80, which is calculated via 0x80 + 0.
    */
    if (_nonce == 0x00) {
      _data = abi.encodePacked(bytes1(0xd6), _len, _deployer, bytes1(0x80));

    /*
      A one-byte integer in the [0x00, 0x7f] range uses its own value as a
      length prefix. There is no additional "0x80 + length" prefix that precedes
      it.
    */
    } else if (_nonce <= 0x7f) {

      // @custom:preserve
      // forge-lint: disable-next-line(unsafe-typecast)
      _data = abi.encodePacked(bytes1(0xd6), _len, _deployer, uint8(_nonce));

    /*
      In the case of `nonce > 0x7f` and `nonce <= type(uint8).max`, we have the
      following encoding scheme (the same calculation can be carried over for
      higher nonce bytes): 1. 0xda = 0xc0 (short RLP prefix) + 0x1a (= the bytes
      length of: 0x94 + address + 0x84 + nonce, in hex), 2. 0x94 = 0x80 + 0x14
      (= the bytes length of an address, 20 bytes, in hex), 3. 0x84 = 0x80 +
      0x04 (= the bytes length of the nonce, 4 bytes, in hex).
    */
    } else if (_nonce <= type(uint8).max) {

      // @custom:preserve
      // forge-lint: disable-next-item(unsafe-typecast)
      _data = abi.encodePacked(
        bytes1(0xd7), _len, _deployer, bytes1(0x81), uint8(_nonce)
      );

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    } else if (_nonce <= type(uint16).max) {
      _data = abi.encodePacked(
        bytes1(0xd8), _len, _deployer, bytes1(0x82), uint16(_nonce)
      );

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    } else if (_nonce <= type(uint24).max) {
      _data = abi.encodePacked(
        bytes1(0xd9), _len, _deployer, bytes1(0x83), uint24(_nonce)
      );

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    } else if (_nonce <= type(uint32).max) {
      _data = abi.encodePacked(
        bytes1(0xda), _len, _deployer, bytes1(0x84), uint32(_nonce)
      );

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    } else if (_nonce <= type(uint40).max) {
      _data = abi.encodePacked(
        bytes1(0xdb), _len, _deployer, bytes1(0x85), uint40(_nonce)
      );

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    } else if (_nonce <= type(uint48).max) {
      _data = abi.encodePacked(
        bytes1(0xdc), _len, _deployer, bytes1(0x86), uint48(_nonce)
      );

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    } else if (_nonce <= type(uint56).max) {
      _data = abi.encodePacked(
        bytes1(0xdd), _len, _deployer, bytes1(0x87), uint56(_nonce)
      );

    // @custom:preserve
    // forge-lint: disable-next-item(unsafe-typecast)
    } else {
      _data = abi.encodePacked(
        bytes1(0xde), _len, _deployer, bytes1(0x88), uint64(_nonce)
      );
    }

    // Return the computed address.
    return address(uint160(uint256(keccak256(_data))));
  }

  /**
    Compute the address where a contract will be stored if deployed via
    `deployer` using the `CREATE` opcode. For the specification of the Recursive
    Length Prefix (RLP) encoding scheme, please refer to p. 19 of the Ethereum
    Yellow Paper and the Ethereum Wiki. All contract accounts on Ethereum are
    initiated with `nonce = 1`. Thus, the first contract address created by
    another contract is calculated with a non-zero nonce.

    @param _nonce The next 32-byte nonce of the deployer address.

    @return _ The 20-byte address where a contract will be stored.
  */
  function computeCreateAddress (
    uint256 _nonce
  ) public view returns (address) {
    return computeCreateAddress(address(this), _nonce);
  }

  /**
    Compute the address where a contract will be stored if deployed via
    `_deployer` using the `CREATE2` opcode. Any change in the `_initCodeHash` or
    `_salt` values will result in a new destination address. This implementation
    is based on OpenZeppelin.

    @param _salt The 32-byte value used to create the contract address.
    @param _initCodeHash The 32-byte bytecode digest of the contract creation
      bytecode.
    @param _deployer The 20-byte deployer address.

    @return _ The 20-byte address where a contract will be stored.
  */
  function computeCreate2Address (
    bytes32 _salt,
    bytes32 _initCodeHash,
    address _deployer
  ) public pure returns (address) {
    address _computedAddressOutput;

    // @custom:preserve
    // |                      | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
    // |----------------------|---------------------------------------------------------------------------|
    // | initCodeHash         |                                                        CCCCCCCCCCCCC...CC |
    // | salt                 |                                      BBBBBBBBBBBBB...BB                   |
    // | deployer             | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
    // | 0xFF                 |            FF                                                             |
    // |----------------------|---------------------------------------------------------------------------|
    // | memory               | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
    // | keccak256(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |
    assembly ("memory-safe") {
      let _ptr := mload(0x40)
      mstore(add(_ptr, 0x40), _initCodeHash)
      mstore(add(_ptr, 0x20), _salt)
      mstore(_ptr, _deployer)
      let _start := add(_ptr, 0x0b)
      mstore8(_start, 0xff)
      _computedAddressOutput := keccak256(_start, 85)
    }
    return _computedAddressOutput;
  }

  /**
    Compute the address where a contract will be stored if deployed via this
    contract using the `CREATE2` opcode. Any change in the `_initCodeHash` or
    `_salt` values will result in a new destination address. This implementation
    is based on OpenZeppelin.

    @param _salt The 32-byte value used to create the contract address.
    @param _initCodeHash The 32-byte bytecode digest of the contract creation
      bytecode.

    @return _ The 20-byte address where a contract will be stored.
  */
  function computeCreate2Address (
    bytes32 _salt,
    bytes32 _initCodeHash
  ) public view returns (address) {
    return computeCreate2Address(_salt, _initCodeHash, address(this));
  }

  /**
    Compute the address where a contract will be stored if deployed via
    `_deployer` using the `CREATE3` pattern (i.e. without an initcode factor).
    Any change in the `_salt` value will result in a new destination address.
    This implementation is based on Solady.

    @param _salt The 32-byte value used to create the proxy contract address.
    @param _deployer The 20-byte deployer address.

    @return _ The 20-byte address where a contract will be stored.
  */
  function computeCreate3Address (
    bytes32 _salt,
    address _deployer
  ) public pure returns (address) {
    address _computedAddressOutput;
    assembly ("memory-safe") {
      let _ptr := mload(0x40)
      mstore(0x00, _deployer)
      mstore8(0x0b, 0xff)
      mstore(0x20, _salt)
      mstore(0x40,
      hex"21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f")
      mstore(0x14, keccak256(0x0b, 0x55))
      mstore(0x40, _ptr)
      mstore(0x00, 0xd694)
      mstore8(0x34, 0x01)
      _computedAddressOutput := keccak256(0x1e, 0x17)
    }
    return _computedAddressOutput;
  }

  /**
    Compute the address where a contract will be stored if deployed via this
    contract using the `CREATE3` pattern (i.e. without an initcode factor). Any
    change in the `_salt` value will result in a new destination address. This
    implementation is based on Solady.

    @param _salt The 32-byte value used to create the proxy contract address.

    @return _ The 20-byte address where a contract will be stored.
  */
  function computeCreate3Address (
    bytes32 _salt
  ) public view returns (address) {
    return computeCreate3Address(_salt, address(this));
  }

  /**
    Ensure that `_newContract` has non-zero bytes.

    @param _newContract The 20-byte address where the contract was deployed.
  */
  function _requireSuccessfulContractCreation (
    address _newContract
  ) internal view {
    if (_newContract == address(0) || _newContract.code.length == 0) {
      revert FailedContractCreation();
    }
  }

  /**
    Deploy a new contract via calling the `CREATE` opcode using the creation
    bytecode `_initCode` and `msg.value` as inputs. In order to save deployment
    costs, we do not sanity check the `_initCode` length. Note that if
    `msg.value` is non-zero, `_initCode` must have a `payable` constructor.

    @param _initCode The creation bytecode.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate (
    bytes memory _initCode
  ) public payable returns (address) {
    address _newContractOutput;
    assembly ("memory-safe") {
      _newContractOutput := create(callvalue(), add(_initCode, 0x20), mload(
      _initCode))
    }
    _requireSuccessfulContractCreation(_newContractOutput);
    emit ContractCreation(_newContractOutput);
    return _newContractOutput;
  }

  /**
    Deploy and initialize a new contract via calling the `CREATE` opcode and
    using the creation bytecode `_initCode`, the initialization call `_data`,
    the struct for the payable amounts `_values`, the refund address
    `_refundAddress`, and `msg.value` as inputs. In order to save deployment
    costs, we do not sanity check the `_initCode` length. Note that if
    `_values.constructorAmount` is non-zero, `_initCode` must have a payable
    constructor. This function allows for reentrancy. Please ensure that
    malicious reentrant calls cannot affect your smart contract.

    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific `payable` amounts for the deployment and
      initialization call. *
    @param _refundAddress The 20-byte address where any excess Ether is returned
      to.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreateAndInit (
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values,
    address _refundAddress
  ) public payable returns (address) {
    address _newContractOutput;
    assembly ("memory-safe") {
      _newContractOutput := create(mload(_values), add(_initCode, 0x20), mload(
      _initCode))
    }
    _requireSuccessfulContractCreation(_newContractOutput);
    emit ContractCreation(_newContractOutput);

    // Initialize the contract after creation.
    (bool _success, bytes memory _returnData) = _newContractOutput.call{
      value: _values.initCallAmount }(
      _data
    );
    if (!_success) {
      revert FailedContractinitialization(_returnData);
    }

    /*
      Any Ether previously forced into this contract (e.g. by using the
      `SELFDESTRUCT` opcode) will be part of the refund transaction.
    */
    if (address(this).balance != 0) {
      (_success, _returnData) = _refundAddress.call{
        value: address(this).balance }(
        ""
      );
      if (!_success) {
        revert FailedEtherTransfer(_returnData);
      }
    }
    return _newContractOutput;
  }

  /**
    Deploy and initialize a new contract via calling the `CREATE` opcode and
    using the creation bytecode `_initCode`, the initialization call `_data`,
    the struct for the payable amounts `_values`, an automatic use of the
    `msg.sender` as refund address, and `msg.value` as inputs. In order to save
    deployment costs, we do not sanity check the `_initCode` length. Note that
    if `_values.constructorAmount` is non-zero, `_initCode` must have a payable
    constructor. This function allows for reentrancy. Please ensure that
    malicious reentrant calls cannot affect your smart contract.

    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific `payable` amounts for the deployment and
      initialization call. *

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreateAndInit (
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values
  ) public payable returns (address) {
    return deployCreateAndInit(_initCode, _data, _values, msg.sender);
  }

  /**
    Ensure that the contract initialization call to `_implementation` was
    successful.

    @param _success The boolean success condition.
    @param _returnData The return data from the contract initialization call.
    @param _implementation The 20-byte address where the implementation was
      deployed.
  */
  function _requireSuccessfulContractinitialization (
    bool _success,
    bytes memory _returnData,
    address _implementation
  ) internal view {
    if (!_success || _implementation.code.length == 0) {
      revert FailedContractinitialization(_returnData);
    }
  }

  /**
    Deploy a new EIP-1167 minimal proxy contract using the `CREATE` opcode and
    initialize the implementation contract using the implementation address
    `_implementation`, the initialization code `_data`, and `msg.value` as
    inputs. Note that if `msg.value` is non-zero, the initializer function
    called via `_data` must be payable. This function allows for reentrancy.
    Please ensure that malicious reentrant calls cannot affect your smart
    contract.

    @param _implementation The 20-byte implementation contract address.
    @param _data The initialization code that is passed to the deployed proxy
      contract.

    @return _ The 20-byte address where the clone was deployed.
  */
  function deployCreateClone (
    address _implementation,
    bytes memory _data
  ) public payable returns (address) {
    bytes20 _implementationInBytes = bytes20(_implementation);

    // Create the proxy contract.
    address _proxyOutput;
    assembly ("memory-safe") {
      let _clone := mload(0x40)
      mstore(_clone,
      hex"3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000")
      mstore(add(_clone, 0x14), _implementationInBytes)
      mstore(add(_clone, 0x28),
      hex"5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000")
      _proxyOutput := create(0, _clone, 0x37)
    }
    if (_proxyOutput == address(0)) {
      revert FailedContractCreation();
    }
    emit ContractCreation(_proxyOutput);

    // Initialize the proxy's implementation.
    (bool _success, bytes memory _returnData) = _proxyOutput.call{
      value: msg.value }(
      _data
    );
    _requireSuccessfulContractinitialization(
      _success, _returnData, _implementation
    );
    return _proxyOutput;
  }

  /**
    Deploy a new contract via calling the `CREATE2` opcode and using the salt
    value `_salt`, the creation bytecode `_initCode`, and `msg.value` as inputs.
    In order to save deployment costs, we do not sanity check the `_initCode`
    length. Note that if `msg.value` is non-zero, `initCode` must have a payable
    constructor.

    @param _salt The 32-byte value used to create the contract address.
    @param _initCode The creation bytecode.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate2 (
    bytes32 _salt,
    bytes memory _initCode
  ) public payable returns (address) {
    bytes32 _guardedSalt = _guard(_salt);

    // Create the contract.
    address _newContractOutput;
    assembly ("memory-safe") {
      _newContractOutput := create2(callvalue(), add(_initCode, 0x20), mload(
      _initCode), _guardedSalt)
    }
    _requireSuccessfulContractCreation(_newContractOutput);
    emit ContractCreation(_newContractOutput, _guardedSalt);
    return _newContractOutput;
  }

  /**
    Deploy a new contract via calling the `CREATE2` opcode and using the
    creation bytecode `_initCode` and `msg.value` as inputs. The salt value is
    calculated pseudorandomly using a diverse selection of block and transaction
    properties. This approach does not guarantee true randomness! In order to
    save deployment costs, we do not sanity check the `_initCode` length. Note
    that if `msg.value` is non-zero, `_initCode` must have a payable
    constructor.

    @param _initCode The creation bytecode.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate2 (
    bytes memory _initCode
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate2`.
    */
    return deployCreate2(_generateSalt(), _initCode);
  }

  /**
    Deploy and initialize a new contract via calling the `CREATE2` opcode and
    using the salt value `_salt`, the creation bytecode `_initCode`, the
    initialization code `_data`, the struct for payable amounts `_values`, the
    refund address `_refundAddress`, and `msg.value` as inputs. In order to save
    deployment costs, we do not sanity check the `_initCode` length. Note that
    if `_values.constructorAmount` is non-zero, `_initCode` must have a payable
    constructor. This function allows for reentrancy. Please ensure that
    malicious reentrant calls cannot affect your smart contract.

    @param _salt The 32-byte value used to create the contract address.
    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific payable amounts for the deployment and
      initialization calls.
    @param _refundAddress The 20-byte address where any excess Ether is
      returned.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate2AndInit (
    bytes32 _salt,
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values,
    address _refundAddress
  ) public payable returns (address) {
    bytes32 _guardedSalt = _guard(_salt);

    // Create the new contract.
    address _newContractOutput;
    assembly ("memory-safe") {
      _newContractOutput := create2(mload(_values), add(_initCode, 0x20), mload(
      _initCode), _guardedSalt)
    }
    _requireSuccessfulContractCreation(_newContractOutput);
    emit ContractCreation(_newContractOutput, _guardedSalt);

    // Initialize the new contract.
    (bool _success, bytes memory _returnData) = _newContractOutput.call{
      value: _values.initCallAmount }(
      _data
    );
    if (!_success) {
      revert FailedContractinitialization(_returnData);
    }

    /*
      Any Ether previously forced into this contract (e.g. by using the
      `SELFDESTRUCT` opcode) will be part of the refund transaction.
    */
    if (address(this).balance != 0) {
      (_success, _returnData) = _refundAddress.call{
        value: address(this).balance }(
        ""
      );
      if (!_success) {
        revert FailedEtherTransfer(_returnData);
      }
    }
    return _newContractOutput;
  }

  /**
    Deploy and initialize a new contract via calling the `CREATE2` opcode and
    using the salt value `_salt`, the creation bytecode `_initCode`, the
    initialization code `_data`, the struct for payable amounts `_values`, the
    refund address defaulting to `msg.sender`, and `msg.value` as inputs. In
    order to save deployment costs, we do not sanity check the `_initCode`
    length. Note that if `_values.constructorAmount` is non-zero, `_initCode`
    must have a payable constructor. This function allows for reentrancy. Please
    ensure that malicious reentrant calls cannot affect your smart contract.

    @param _salt The 32-byte value used to create the contract address.
    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific payable amounts for the deployment and
      initialization calls.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate2AndInit (
    bytes32 _salt,
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate2AndInit`.
    */
    return deployCreate2AndInit(_salt, _initCode, _data, _values, msg.sender);
  }

  /**
    Deploy and initialize a new contract via calling the `CREATE2` opcode and
    using the creation bytecode `_initCode`, the initialization code `_data`,
    the struct for payable amounts `_values`, the refund address
    `_refundAddress`, and `msg.value` as inputs. The salt value is calculated
    pseudorandomly using a diverse selection of block and transaction
    properties. This approach does not guarantee true randomness! In order to
    save deployment costs, we do not sanity check the `_initCode` length. Note
    that if `_values.constructorAmount` is non-zero, `_initCode` must have a
    payable constructor. This function allows for reentrancy. Please ensure that
    malicious reentrant calls cannot affect your smart contract.

    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific payable amounts for the deployment and
      initialization calls.
    @param _refundAddress The 20-byte address where any excess Ether is
      returned.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate2AndInit (
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values,
    address _refundAddress
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate2AndInit`.
    */
    return deployCreate2AndInit(
      _generateSalt(), _initCode, _data, _values, _refundAddress
    );
  }

  /**
    Deploy and initialize a new contract via calling the `CREATE2` opcode and
    using the creation bytecode `_initCode`, the initialization code `_data`,
    the struct for payable amounts `_values`, the refund address defaulting to
    `msg.sender`, and `msg.value` as inputs. The salt value is calculated
    pseudorandomly using a diverse selection of block and transaction
    properties. This approach does not guarantee true randomness! In order to
    save deployment costs, we do not sanity check the `_initCode` length. Note
    that if `_values.constructorAmount` is non-zero, `_initCode` must have a
    payable constructor. This function allows for reentrancy. Please ensure that
    malicious reentrant calls cannot affect your smart contract.

    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific payable amounts for the deployment and
      initialization calls.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate2AndInit (
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate2AndInit`.
    */
    return deployCreate2AndInit(
      _generateSalt(), _initCode, _data, _values, msg.sender
    );
  }

  /**
    Deploy a new EIP-1167 minimal proxy contract using the `CREATE2` opcode and
    the salt value `_salt`, then initialize the implementation contract using
    the implementation address `_implementation`, the initialization code
    `_data`, and `msg.value` as inputs. Note that if `msg.value` is non-zero,
    the initializer function called via `_data` must be payable. This function
    allows for reentrancy. Please ensure that malicious reentrant calls cannot
    affect your smart contract.

    @param _salt The 32-byte value used to create the proxy contract address.
    @param _implementation The 20-byte implementation contract address.
    @param _data The initialization code that is passed to the deployed proxy
      contract.

    @return _ The 20-byte address where the clone was deployed.
  */
  function deployCreate2Clone (
    bytes32 _salt,
    address _implementation,
    bytes memory _data
  ) public payable returns (address) {
    bytes32 _guardedSalt = _guard(_salt);
    bytes20 _implementationInBytes = bytes20(_implementation);

    // Deploy the proxy contract.
    address _proxyOutput;
    assembly ("memory-safe") {
      let _clone := mload(0x40)
      mstore(_clone,
      hex"3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000")
      mstore(add(_clone, 0x14), _implementationInBytes)
      mstore(add(_clone, 0x28),
      hex"5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000")
      _proxyOutput := create2(0, _clone, 0x37, _guardedSalt)
    }
    if (_proxyOutput == address(0)) {
      revert FailedContractCreation();
    }
    emit ContractCreation(_proxyOutput, _guardedSalt);

    // Initialize the implementation.
    (bool _success, bytes memory _returnData) = _proxyOutput.call{
      value: msg.value }(
      _data
    );
    _requireSuccessfulContractinitialization(
      _success, _returnData, _implementation
    );
    return _proxyOutput;
  }

  /**
    Deploy a new EIP-1167 minimal proxy contract using the `CREATE2` opcode and
    then initialize the implementation contract using the implementation address
    `_implementation`, the initialization code `_data`, and `msg.value` as
    inputs. The salt value is calculated pseudorandomly using a diverse
    selection of block and transaction properties. This approach does not
    guarantee true randomness! Note that if `msg.value` is non-zero, the
    initializer function called via `_data` must be payable. This function
    allows for reentrancy. Please ensure that malicious reentrant calls cannot
    affect your smart contract.

    @param _implementation The 20-byte implementation contract address.
    @param _data The initialization code that is passed to the deployed proxy
      contract.

    @return _ The 20-byte address where the clone was deployed.
  */
  function deployCreate2Clone (
    address _implementation,
    bytes memory _data
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate2Clone`.
    */
    return deployCreate2Clone(_generateSalt(), _implementation, _data);
  }

  /**
    Ensure that `_newContract` is a non-zero byte contract.

    @param _success The boolean success condition.
    @param _newContract The 20-byte address where the contract was deployed.
  */
  function _requireSuccessfulContractCreation (
    bool _success,
    address _newContract
  ) internal view {

    /*
      Note that reverting if `newContract == address(0)` isn't strictly
      necessary here, as if the deployment fails, `success == false` should
      already hold. However, since the `CreateX` contract should be usable and
      safe on a wide range of chains, this check is cheap enough that there is
      no harm in including it (security > gas optimisations). It can potentially
      protect against unexpected chain behaviour or a hypothetical compiler bug
      that doesn't surface the call success status properly.
    */
    if (
      !_success || _newContract == address(0) || _newContract.code.length == 0
    ) {
      revert FailedContractCreation();
    }
  }

  /**
    Deploy a new contract via the `CREATE3` pattern (i.e. without an initcode
    factor) and using the salt value `_salt`, the creation bytecode `_initCode`,
    and `msg.value` as inputs. In order to save deployment costs, we do not
    sanity check the `_initCode` length. Note that if `msg.value` is non-zero,
    `_initCode` must have a payable constructor. This implementation is based on
    Solmate. We strongly recommend implementing a permissioned deploy protection
    by setting the first 20 bytes equal to `msg.sender` in the `salt` to prevent
    maliciously-frontrun proxy deployments on other chains.

    @param _salt The 32-byte value used to create the proxy contract address.
    @param _initCode The creation bytecode.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate3 (
    bytes32 _salt,
    bytes memory _initCode
  ) public payable returns (address) {
    bytes32 _guardedSalt = _guard(_salt);
    bytes memory _proxyChildBytecode = hex"67363d3d37363d34f03d5260086018f3";

    // Deploy the proxy.
    address _proxy;
    assembly ("memory-safe") {
      _proxy := create2(0, add(_proxyChildBytecode, 32), mload(
      _proxyChildBytecode), _guardedSalt)
    }
    if (_proxy == address(0)) {
      revert FailedContractCreation();
    }
    emit Create3ProxyContractCreation(_proxy, _guardedSalt);

    // Deploy the contract.
    address _newContractOutput = computeCreate3Address(_guardedSalt);
    (bool _success, ) = _proxy.call{ value: msg.value }(_initCode);
    _requireSuccessfulContractCreation(_success, _newContractOutput);
    emit ContractCreation(_newContractOutput);
    return _newContractOutput;
  }

  /**
    Deploy a new contract via the `CREATE3` pattern (i.e. without an initcode
    factor) and using the creation bytecode `_initCode` and `msg.value` as
    inputs. The salt value is calculated pseudorandomly using a diverse
    selection of block and transaction properties. This approach does not
    guarantee true randomness! In order to save deployment costs, we do not
    sanity check the `_initCode` length. Note that if `msg.value` is non-zero,
    `_initCode` must have a payable constructor. This implementation is based on
    Solmate. We strongly recommend implementing a permissioned deploy protection
    by setting the first 20 bytes equal to `msg.sender` in the `salt` to prevent
    maliciously-frontrun proxy deployments on other chains.

    @param _initCode The creation bytecode.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate3 (
    bytes memory _initCode
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate3`.
    */
    return deployCreate3(_generateSalt(), _initCode);
  }

  /**
    Deploy and initialize a new contract via the `CREATE3` pattern (i.e. without
    an initcode factor) and using the salt value `_salt`, the creation bytecode
    `_initCode`, the initialization code `_data`, the struct for the payable
    amounts `_values`, the refund address `_refundAddress`, and `msg.value` as
    inputs. In order to save deployment costs, we do not sanity check the
    `_initCode` length. Note that if `_values.constructorAmount` is non-zero,
    `_initCode` must have a payable constructor. This implementation is based on
    Solmate. We strongly recommend implementing a permissioned deploy protection
    by setting the first 20 bytes equal to `msg.sender` in the `salt` to prevent
    maliciously-frontrun proxy deployments on other chains. This function allows
    for reentrancy. Please ensure that malicious reentrant calls cannot affect
    your smart contract.

    @param _salt The 32-byte value used to create the proxy contract address.
    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific payable amounts for the deployment and
      initialization calls.
    @param _refundAddress The 20-byte address where any excess Ether is
      returned.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate3AndInit (
    bytes32 _salt,
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values,
    address _refundAddress
  ) public payable returns (address) {
    bytes32 _guardedSalt = _guard(_salt);
    bytes memory _proxyChildBytecode = hex"67363d3d37363d34f03d5260086018f3";

    // Deploy the proxy.
    address _proxy;
    assembly ("memory-safe") {
      _proxy := create2(0, add(_proxyChildBytecode, 32), mload(
      _proxyChildBytecode), _guardedSalt)
    }
    if (_proxy == address(0)) {
      revert FailedContractCreation();
    }
    emit Create3ProxyContractCreation(_proxy, _guardedSalt);

    // Deploy the contract.
    address _newContractOutput = computeCreate3Address(_guardedSalt);
    (bool _success, ) = _proxy.call{ value: _values.constructorAmount }(
      _initCode
    );
    _requireSuccessfulContractCreation(_success, _newContractOutput);
    emit ContractCreation(_newContractOutput);

    // Initialize the new contract.
    bytes memory _returnData;
    (_success, _returnData) = _newContractOutput.call{
      value: _values.initCallAmount }(
      _data
    );
    if (!_success) {
      revert FailedContractinitialization(_returnData);
    }

    /*
      Any Ether previously forced into this contract (e.g. by using the
      `SELFDESTRUCT` opcode) will be part of the refund transaction.
    */
    if (address(this).balance != 0) {
      (_success, _returnData) = _refundAddress.call{
        value: address(this).balance }(
        ""
      );
      if (!_success) {
        revert FailedEtherTransfer(_returnData);
      }
    }
    return _newContractOutput;
  }

  /**
    Deploy and initialize a new contract via the `CREATE3` pattern (i.e. without
    an initcode factor) and using the salt value `_salt`, the creation bytecode
    `_initCode`, the initialization code `_data`, the struct for the payable
    amounts `_values`, the refund address defaulting to `msg.sender`, and
    `msg.value` as inputs. In order to save deployment costs, we do not sanity
    check the `_initCode` length. Note that if `_values.constructorAmount` is
    non-zero, `_initCode` must have a payable constructor. This implementation
    is based on Solmate. We strongly recommend implementing a permissioned
    deploy protection by setting the first 20 bytes equal to `msg.sender` in the
    `salt` to prevent maliciously-frontrun proxy deployments on other chains.
    This function allows for reentrancy. Please ensure that malicious reentrant
    calls cannot affect your smart contract.

    @param _salt The 32-byte value used to create the proxy contract address.
    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific payable amounts for the deployment and
      initialization calls.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate3AndInit (
    bytes32 _salt,
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate3AndInit`.
    */
    return deployCreate3AndInit(_salt, _initCode, _data, _values, msg.sender);
  }

  /**
    Deploy and initialize a new contract via the `CREATE3` pattern (i.e. without
    an initcode factor) and using the creation bytecode `_initCode`, the
    initialization code `_data`, the struct for the payable amounts `_values`,
    the refund address `_refundAddress`, and `msg.value` as inputs. The salt
    value is calculated pseudorandomly using a diverse selection of block and
    transaction properties. This approach does not guarantee true randomness! In
    order to save deployment costs, we do not sanity check the `_initCode`
    length. Note that if `_values.constructorAmount` is non-zero, `_initCode`
    must have a payable constructor. This implementation is based on Solmate. We
    strongly recommend implementing a permissioned deploy protection by setting
    the first 20 bytes equal to `msg.sender` in the `salt` to prevent
    maliciously-frontrun proxy deployments on other chains. This function allows
    for reentrancy. Please ensure that malicious reentrant calls cannot affect
    your smart contract.

    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific payable amounts for the deployment and
      initialization calls.
    @param _refundAddress The 20-byte address where any excess Ether is
      returned.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate3AndInit (
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values,
    address _refundAddress
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate3AndInit`.
    */
    return deployCreate3AndInit(
      _generateSalt(), _initCode, _data, _values, _refundAddress
    );
  }

  /**
    Deploy and initialize a new contract via the `CREATE3` pattern (i.e. without
    an initcode factor) and using the creation bytecode `_initCode`, the
    initialization code `_data`, the struct for the payable amounts `_values`,
    the refund address defaulting to `msg.sender`, and `msg.value` as inputs.
    The salt value is calculated pseudorandomly using a diverse selection of
    block and transaction properties. This approach does not guarantee true
    randomness! In order to save deployment costs, we do not sanity check the
    `_initCode` length. Note that if `_values.constructorAmount` is non-zero,
    `_initCode` must have a payable constructor. This implementation is based on
    Solmate. We strongly recommend implementing a permissioned deploy protection
    by setting the first 20 bytes equal to `msg.sender` in the `salt` to prevent
    maliciously-frontrun proxy deployments on other chains. This function allows
    for reentrancy. Please ensure that malicious reentrant calls cannot affect
    your smart contract.

    @param _initCode The creation bytecode.
    @param _data The initialization code that is passed to the deployed
      contract.
    @param _values The specific payable amounts for the deployment and
      initialization calls.

    @return _ The 20-byte address where the contract was deployed.
  */
  function deployCreate3AndInit (
    bytes memory _initCode,
    bytes memory _data,
    Values memory _values
  ) public payable returns (address) {

    /*
      Note that the safeguarding function `_guard` is called as part of the
      overloaded function `deployCreate3AndInit`.
    */
    return deployCreate3AndInit(
      _generateSalt(), _initCode, _data, _values, msg.sender
    );
  }
}


// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { IMulticall3 } from "./interfaces/IMulticall3.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title A Multicall3 Implementation
  @custom:blame Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"
  @custom:preserve

  This contract allows a caller to aggregate results from multiple function
  calls. This is a stylistically-modified version of the canonical Multicall3
  contract used by many Ethereum frontends.

  This is a modified version of the contract by Michael Elliot, Joshua Levine,
  Nick Johnson, Andreas Bigger, and Matt Solomon. Do not blame or bother them,
  or upstream Multicall3, regarding any issues you find with this contract.

  @custom:date January 15th, 2026.
*/
contract Multicall3 is
  IMulticall3 {

  /**
    The EIP-2935 historical block hash storage contract address. This system
    contract stores block hashes beyond the 256 block limit of the `blockhash`
    opcode, providing access to up to 8192 historical block hashes.
  */
  address public constant HISTORY_STORAGE =
    0x0000F90827F1C53a10cb7A02335B175320002935;

  /**
    Return the chain ID.

    @return _ The ID of the chain.
  */
  function getChainId () external view returns (uint256) {
    return block.chainid;
  }

  /**
    Return the current block number.

    @return _ The current block number.
  */
  function getBlockNumber () external view returns (uint256) {
    return block.number;
  }

  /**
    Return the current block timestamp.

    @return _ The timestamp of the current block.
  */
  function getCurrentBlockTimestamp () external view returns (uint256) {
    return block.timestamp;
  }

  /**
    Return the hash of a specific block. First tries the `blockhash` opcode
    (works for the most recent 256 blocks), then falls back to the EIP-2935
    historical block hash storage contract (works for up to 8192 blocks).

    @param _blockNumber The block number to get the hash for.

    @return _ The hash of the block, or zero if unavailable.
  */
  function getBlockHash (
    uint256 _blockNumber
  ) external view returns (bytes32) {

    // Try the blockhash opcode first (works for last 256 blocks).
    bytes32 _blockHash = blockhash(_blockNumber);
    if (_blockHash != bytes32(0)) {
      return _blockHash;
    }

    /*
      Fall back to EIP-2935 historical storage for older blocks. The system
      contract returns the hash when called with the block number.
    */
    (bool _success, bytes memory _result) = HISTORY_STORAGE.staticcall(
      abi.encode(_blockNumber)
    );
    if (_success && _result.length == 32) {
      _blockHash = abi.decode(_result, (bytes32));
    }
    return _blockHash;
  }

  /**
    Return the most recent block hash.

    @return _ The block hash of the previous block.
  */
  function getLastBlockHash () external view returns (bytes32) {
    unchecked {
      return blockhash(block.number - 1);
    }
  }

  /**
    Return the current block gas limit.

    @return _ The gas limit of the current block.
  */
  function getCurrentBlockGasLimit () external view returns (uint256) {
    return block.gaslimit;
  }

  /**
    Return the base fee of the current block.

    @return _ The base fee of the current block.
  */
  function getBasefee () external view returns (uint256) {
    return block.basefee;
  }

  /**
    Return the RANDAO mix value of the previous block.

    @return _ The current block's previous block's RANDAO mix value.
  */
  function getCurrentBlockPrevrandao () external view returns (uint256) {
    return block.prevrandao;
  }

  /**
    Return the current block coinbase; the address of the block reward
    beneficiary.

    @return _ The current block coinbase.
  */
  function getCurrentBlockCoinbase () external view returns (address) {
    return block.coinbase;
  }

  /**
    Return the Ether balance of an address.

    @param _address The address to check the balance of.

    @return _ The Ether balance of `_address`.
  */
  function getEthBalance (
    address _address
  ) external view returns (uint256) {
    return _address.balance;
  }

  /**
    Allow the caller to perform aggregated calls and revert if any fail.

    @param _calls The calls to execute.

    @return _ A tuple consisting of (the current block number, and an array of
      the return data from each call).
  */
  function aggregate (
    Call[] calldata _calls
  ) external payable returns (uint256, bytes[] memory) {
    bytes[] memory _returnData = new bytes[](_calls.length);
    for (uint256 i = 0; i < _calls.length; i++) {
      (bool _success, bytes memory _ret) = _calls[i].target.call(
        _calls[i].callData
      );
      require(_success, "Multicall3: call failed");
      _returnData[i] = _ret;
    }
    return (block.number, _returnData);
  }

  /**
    Aggregate calls, returning success status and data for each.

    @param _requireSuccess Whether or not all calls must succeed.
    @param _calls The calls to execute.

    @return _ An array of the `Result`s containing the success status and return
      data from each call.
  */
  function tryAggregate (
    bool _requireSuccess,
    Call[] calldata _calls
  ) public payable returns (Result[] memory) {
    Result[] memory _results = new Result[](_calls.length);
    for (uint256 i = 0; i < _calls.length; i++) {
      (bool _success, bytes memory _ret) = _calls[i].target.call(
        _calls[i].callData
      );
      if (_requireSuccess) {
        require(_success, "Multicall3: call failed");
      }
      _results[i] = Result(_success, _ret);
    }
    return _results;
  }

  /**
    Aggregate calls with block info, returning success status and data for each.

    @param _requireSuccess Whether or not all calls must succeed.
    @param _calls The calls to execute.

    @return _ A tuple consisting of (the current block number, the current block
      hash, and an array of the `Result`s containing the success status and
      return data from each call).
  */
  function tryBlockAndAggregate (
    bool _requireSuccess,
    Call[] calldata _calls
  ) public payable returns (uint256, bytes32, Result[] memory) {
    Result[] memory _results = tryAggregate(_requireSuccess, _calls);
    return (block.number, blockhash(block.number), _results);
  }

  /**
    Aggregate calls with block info, reverting if any fail.

    @param _calls The calls to execute.

    @return _ A tuple consisting of (the current block number, the current block
      hash, and an array of the `Result`s containing the success status and
      return data from each call).
  */
  function blockAndAggregate (
    Call[] calldata _calls
  ) external payable returns (uint256, bytes32, Result[] memory) {
    return tryBlockAndAggregate(true, _calls);
  }

  /**
    Aggregate calls with configurable failure handling for each call.

    @param _calls The calls to execute.

    @return _ An array of the `Result`s containing the success status and return
      data from each call.
  */
  function aggregate3 (
    Call3[] calldata _calls
  ) external payable returns (Result[] memory) {
    Result[] memory _results = new Result[](_calls.length);
    for (uint256 i = 0; i < _calls.length; i++) {
      Call3 calldata _call = _calls[i];
      Result memory _result = _results[i];
      (_result.success, _result.returnData) = _call.target.call(_call.callData);

      // @custom:preserve
      // Revert if a call fails and failure is not allowed.
      // `allowFailure` := calldataload(add(calli, 0x20))
      // `success` := mload(result)
      // mstore 0x00 is `bytes32(bytes4(keccak256("Error(string)")))`
      // mstore 0x04 is the data offset
      // mstore 0x24 is the length of the following revert string
      // mstore 0x44 is `bytes32(abi.encodePacked("Multicall3: call failed"))`
      assembly {
        if iszero(or(calldataload(add(_call, 0x20)), mload(_result))) {
          mstore(0x00,
          0x08c379a000000000000000000000000000000000000000000000000000000000)
          mstore(0x04,
          0x0000000000000000000000000000000000000000000000000000000000000020)
          mstore(0x24,
          0x0000000000000000000000000000000000000000000000000000000000000017)
          mstore(0x44,
          0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
          revert(0x00, 0x64)
        }
      }
    }
    return _results;
  }

  /**
    Aggregate calls with value and configurable failure handling.

    @param _calls The calls to execute.

    @return _ An array of the `Result`s containing the success status and return
      data from each call.
  */
  function aggregate3Value (
    Call3Value[] calldata _calls
  ) external payable returns (Result[] memory) {
    uint256 _accumulator;
    Result[] memory _results = new Result[](_calls.length);
    for (uint256 i = 0; i < _calls.length; i++) {
      Call3Value calldata _call = _calls[i];
      Result memory _result = _results[i];
      uint256 _callValue = _call.value;
      unchecked {
        _accumulator += _callValue;
      }
      (_result.success, _result.returnData) = _call.target.call{
        value: _callValue }(
        _call.callData
      );

      // @custom:preserve
      // Revert if a call fails and failure is not allowed.
      // `allowFailure` := calldataload(add(calli, 0x20))
      // `success` := mload(result)
      // mstore 0x00 is `bytes32(bytes4(keccak256("Error(string)")))`
      // mstore 0x04 is the data offset
      // mstore 0x24 is the length of the following revert string
      // mstore 0x44 is `bytes32(abi.encodePacked("Multicall3: call failed"))`
      assembly {
        if iszero(or(calldataload(add(_call, 0x20)), mload(_result))) {
          mstore(0x00,
          0x08c379a000000000000000000000000000000000000000000000000000000000)
          mstore(0x04,
          0x0000000000000000000000000000000000000000000000000000000000000020)
          mstore(0x24,
          0x0000000000000000000000000000000000000000000000000000000000000017)
          mstore(0x44,
          0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
          revert(0x00, 0x84)
        }
      }
    }

    // Ensure the entire `msg.value` is accounted for and return.
    require(msg.value == _accumulator, "Multicall3: value mismatch");
    return _results;
  }
}


// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title A Multicall3 Implementation Interface
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
interface IMulticall3 {

  /**
    A single call to execute.

    @param target The target address being called.
    @param callData The data of the call being executed on `target`.
  */
  struct Call {
    address target;
    bytes callData;
  }

  /**
    A single call to execute with optional failure tolerance.

    @param target The target address being called.
    @param allowFailure Whether or not to tolerate failure of this call.
    @param callData The data of the call being executed on `target`.
  */
  struct Call3 {
    address target;
    bool allowFailure;
    bytes callData;
  }

  /**
    A single call to execute with optional failure tolerance and Ether value.

    @param target The target address being called.
    @param allowFailure Whether or not to tolerate failure of this call.
    @param value The Ether value to send with this call.
    @param callData The data of the call being executed on `target`.
  */
  struct Call3Value {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
  }

  /**
    The result of a single call.

    @param success Whether or not the call succeeded.
    @param returnData The data returned by the call.
  */
  struct Result {
    bool success;
    bytes returnData;
  }

  /**
    The EIP-2935 historical block hash storage contract address. This system
    contract stores block hashes beyond the 256 block limit of the `blockhash`
    opcode, providing access to up to 8192 historical block hashes.

    @return _ TODO
  */
  function HISTORY_STORAGE () external pure returns (address);

  /**
    Return the chain ID.

    @return _ The ID of the chain.
  */
  function getChainId () external view returns (uint256);

  /**
    Return the current block number.

    @return _ The current block number.
  */
  function getBlockNumber () external view returns (uint256);

  /**
    Return the current block timestamp.

    @return _ The timestamp of the current block.
  */
  function getCurrentBlockTimestamp () external view returns (uint256);

  /**
    Return the hash of a specific block. First tries the `blockhash` opcode
    (works for the most recent 256 blocks), then falls back to the EIP-2935
    historical block hash storage contract (works for up to 8192 blocks).

    @param _blockNumber The block number to get the hash for.

    @return _ The hash of the block, or zero if unavailable.
  */
  function getBlockHash (
    uint256 _blockNumber
  ) external view returns (bytes32);

  /**
    Return the most recent block hash.

    @return _ The block hash of the previous block.
  */
  function getLastBlockHash () external view returns (bytes32);

  /**
    Return the current block gas limit.

    @return _ The gas limit of the current block.
  */
  function getCurrentBlockGasLimit () external view returns (uint256);

  /**
    Return the base fee of the current block.

    @return _ The base fee of the current block.
  */
  function getBasefee () external view returns (uint256);

  /**
    Return the RANDAO mix value of the previous block.

    @return _ The current block's previous block's RANDAO mix value.
  */
  function getCurrentBlockPrevrandao () external view returns (uint256);

  /**
    Return the current block coinbase; the address of the block reward
    beneficiary.

    @return _ The current block coinbase.
  */
  function getCurrentBlockCoinbase () external view returns (address);

  /**
    Return the Ether balance of an address.

    @param _address The address to check the balance of.

    @return _ The Ether balance of `_address`.
  */
  function getEthBalance (
    address _address
  ) external view returns (uint256);

  /**
    Allow the caller to perform aggregated calls and revert if any fail.

    @param _calls The calls to execute.

    @return _ A tuple consisting of (the current block number, and an array of
      the return data from each call).
  */
  function aggregate (
    Call[] calldata _calls
  ) external payable returns (uint256, bytes[] memory);

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
  ) external payable returns (Result[] memory);

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
  ) external payable returns (uint256, bytes32, Result[] memory);

  /**
    Aggregate calls with block info, reverting if any fail.

    @param _calls The calls to execute.

    @return _ A tuple consisting of (the current block number, the current block
      hash, and an array of the `Result`s containing the success status and
      return data from each call).
  */
  function blockAndAggregate (
    Call[] calldata _calls
  ) external payable returns (uint256, bytes32, Result[] memory);

  /**
    Aggregate calls with configurable failure handling for each call.

    @param _calls The calls to execute.

    @return _ An array of the `Result`s containing the success status and return
      data from each call.
  */
  function aggregate3 (
    Call3[] calldata _calls
  ) external payable returns (Result[] memory);

  /**
    Aggregate calls with value and configurable failure handling.

    @param _calls The calls to execute.

    @return _ An array of the `Result`s containing the success status and return
      data from each call.
  */
  function aggregate3Value (
    Call3Value[] calldata _calls
  ) external payable returns (Result[] memory);
}


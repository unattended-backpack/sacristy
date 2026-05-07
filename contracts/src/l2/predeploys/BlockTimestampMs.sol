// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @custom:predeploy 0x4200000000000000000000000000000000000050
/// @title BlockTimestampMs
/// @notice Sigil-specific predeploy exposing the per-block Unix-millisecond
///         wall-time the sequencer chose for the L2 block. The EVM
///         `TIMESTAMP` opcode continues to return `block.timestamp` in
///         seconds (Ethereum compatibility); contracts wanting
///         millisecond resolution call `blockTimestampMs()` on this
///         predeploy.
///
///         The state-transition function (STF) writes the ms value
///         from a fixed system caller as a pre-execution change at
///         block-build start, in the EIP-2935 / EIP-4788 style. No
///         synthetic transaction lands in the block body — the write
///         is a state-only update bound by the post-block state root,
///         same shape as the BlockHash and BeaconRoot predeploys.
///
///         The blob's batch-format `first_timestamp` and per-block
///         `delta_timestamp` carry the ms value end-to-end through
///         sequencer → batcher → deriver → prover-program; all three
///         apply the identical pre-execution change so re-execution
///         is bit-identical.
contract BlockTimestampMs {

    /// @notice The system caller — fixed address used for STF
    ///         pre-execution writes (same value as EIP-2935 /
    ///         EIP-4788).
    address internal constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

    /// @notice The per-block Unix-millisecond timestamp the sequencer
    ///         chose. Updated atomically at the start of each block
    ///         via the system call below; readable by any L2
    ///         contract via [`blockTimestampMs`].
    uint256 public blockTimestampMs;

    /// @notice Fallback called by the system caller with the new ms
    ///         value as exactly 32 bytes of calldata.
    ///
    ///         The pre-execution change passes the ms timestamp as a
    ///         single 32-byte word; we reject any non-system caller
    ///         and any calldata length that isn't 32 to keep the
    ///         interface tight. No event emitted — the state slot is
    ///         the source of truth and emitting on every block would
    ///         double the cost for no extra information.
    fallback() external {
        require(msg.sender == SYSTEM_ADDRESS, "BlockTimestampMs: not system");
        require(msg.data.length == 32, "BlockTimestampMs: bad calldata");
        uint256 ms;
        assembly {
            ms := calldataload(0)
        }
        blockTimestampMs = ms;
    }
}

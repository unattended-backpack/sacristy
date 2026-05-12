// SPDX-License-Identifier: MIT

// `blobhash` opcode (EIP-4844) is supported from solc 0.8.24+.
// Pin to a Cancun-aware compiler explicitly.
pragma solidity ^0.8.25;

import { ISP1Verifier } from "src/l2/verifier/ISP1Verifier.sol";
import { Types } from "src/l2/lib/Types.sol";
import { Hashing } from "src/l2/lib/Hashing.sol";
import { SafeCall } from "src/l2/lib/SafeCall.sol";
import { SecureMerkleTrie } from "src/l2/lib/SecureMerkleTrie.sol";

/// @title SigilVerifier
/// @notice The unified L1 contract for Sigil. Collapses the OP-stack-style
///         BlobRegistry / DepositQueue / Verifier / Portal into one contract:
///
///         - **Blob registry.** `postBlobs()` pulls every versioned hash off
///           the EIP-4844 `BLOBHASH` opcode and assigns monotonic ids.
///         - **Deposit queue.** `deposit()` appends to a Keccak hash chain
///           and snapshots `(blockNumber, rootAfter)` into the `deposits[]`
///           array on every call. `submitProof()` reads
///           `deposits[newProcessedDepositCount - 1].rootAfter` directly via
///           SLOAD to anchor `newProcessedDepositRoot` — no L1-state MPT
///           walk inside the SNARK. This makes the immutable verifier
///           independent of the L1 state-trie format (i.e., survives any
///           future Ethereum migration to verkle / binary tries).
///         - **Multi-zkVM quorum verifier.** `submitProof()` accepts ≥ QUORUM
///           proofs from distinct zkVM systems (each backed by its own
///           per-system verifier contract conforming to [`ISP1Verifier`]).
///           A single soundness break in one system cannot advance state.
///         - **Withdrawal portal.** Proves and finalizes L2→L1 withdrawals
///           against the proven L2 output root.
///
///         Per `NEW_DERIVATION.md` §"Genesis on the verifier contract", the
///         per-rollup execution config (`chainId`, `minimumBlockGasLimit`,
///         `minimumTxGasLimit`) is stored as immutable contract state and
///         bound by every accepted SNARK's public-input check. One zkVM
///         binary serves N rollups; each deployment binds its own Genesis.
contract SigilVerifier {

  // ============================================================
  //                     IMMUTABLE GENESIS
  // ============================================================

  /// @notice L2 chain id. Bound by the SNARK's public-input check
  ///         so a malicious prover can't substitute a different
  ///         chain_id (which would silently exclude real users'
  ///         signed transactions from the chain).
  uint64 public immutable CHAIN_ID;

  /// @notice L1 chain id this L2 settles to. Bound by every SNARK
  ///         and additionally validated by the validator node at
  ///         startup against the L1 RPC's `eth_chainId` reply
  ///         (catches "pointed at wrong L1" misconfigurations).
  uint64 public immutable L1_CHAIN_ID;

  /// @notice Genesis block timestamp (Unix seconds). Bound by the
  ///         SNARK so the genesis block hash and output root are
  ///         reproducible from the contract's immutables alone.
  uint64 public immutable GENESIS_TIMESTAMP;

  /// @notice Cryptographic floor on the per-block gas limit. Bound
  ///         by every SNARK's public-input check; the prover-program
  ///         enforces `block.blockGasLimit >= MINIMUM_BLOCK_GAS_LIMIT`
  ///         per block. Sequencers may pick any per-blob ceiling
  ///         above this floor — Sigil has no governance gate on
  ///         transitions, so cross-blob changes are unconstrained.
  ///         The floor itself is immutable for the chain's lifetime.
  uint64 public immutable MINIMUM_BLOCK_GAS_LIMIT;

  /// @notice Cryptographic floor on the per-transaction gas-limit
  ///         cap (the EVM's `cfg_env.tx_gas_limit_cap`). Bound by
  ///         every SNARK's public-input check; the prover-program
  ///         enforces `block.txGasLimit >= MINIMUM_TX_GAS_LIMIT` per
  ///         block. Sequencers may pick a higher per-blob cap — same
  ///         shape as `MINIMUM_BLOCK_GAS_LIMIT`. Default at deploy
  ///         time is EIP-7825's Osaka constant `2^24 = 16,777,216`.
  uint64 public immutable MINIMUM_TX_GAS_LIMIT;

  /// @notice Cryptographic floor on the per-blob deployed-code size
  ///         cap (EIP-170, `cfg_env.limit_contract_code_size`).
  ///         Default at deploy time is `24,576`.
  uint64 public immutable MINIMUM_CODE_SIZE;

  /// @notice Cryptographic ceiling on the per-blob deployed-code
  ///         size cap. State-bloat protection — every SNARK's
  ///         public-input check enforces `code_size <=
  ///         MAXIMUM_CODE_SIZE`. Set equal to `MINIMUM_CODE_SIZE`
  ///         at deploy to pin the chain at one value; raise above
  ///         to grant sequencer policy diversity within a range.
  uint64 public immutable MAXIMUM_CODE_SIZE;

  /// @notice Cryptographic floor on the per-blob initcode size cap
  ///         (EIP-3860). Default `49,152`.
  uint64 public immutable MINIMUM_INITCODE_SIZE;

  /// @notice Cryptographic ceiling on the per-blob initcode size
  ///         cap. Same role as `MAXIMUM_CODE_SIZE`.
  uint64 public immutable MAXIMUM_INITCODE_SIZE;

  /// @notice Cryptographic ceiling on the per-action `Call.calldata`
  ///         size for sequencer-space pre-execution calls. Default
  ///         `65,536` bytes. Bound into the SNARK's public input;
  ///         a sequencer that enqueues a call exceeding this
  ///         produces a block whose proof will fail.
  uint64 public immutable MAXIMUM_SEQUENCER_CALLDATA_SIZE;

  /// @notice EIP-2935 historical block hash predeploy.
  address internal constant BLOCK_HASH_HISTORY =
    0x0aAE40c64eE92ca37C98ec0d39c33b22A7d0c1A8;

  // ============================================================
  //                   QUORUM CONFIGURATION
  // ============================================================

  /// @notice Per-zkVM verifier contracts (e.g. SP1 PLONK, RISC Zero
  ///         Groth16, ...). Indexed by system id passed in submitProof.
  address[] public quorumVerifiers;

  /// @notice Verification key per zkVM system, parallel to
  ///         `quorumVerifiers`. The same Rust prover-program is
  ///         compiled against each system; each compilation produces
  ///         its own verification key, which is fixed at deploy time.
  bytes32[] public quorumVKeys;

  /// @notice Minimum distinct zkVM systems whose proofs must verify
  ///         for a `submitProof` call to advance state.
  uint8 public immutable QUORUM;

  // ============================================================
  //                    BLOB REGISTRY STATE
  // ============================================================

  /// @notice `id → versioned_hash`. `postBlobs()` writes here.
  mapping(uint64 => bytes32) public blobVersionedHashes;

  /// @notice Next id to assign. Monotonic.
  uint64 public nextBlobId;

  // ============================================================
  //                   DEPOSIT QUEUE STATE
  // ============================================================

  struct DepositMeta {
    uint64 blockNumber;
    bytes32 rootAfter;
  }

  /// @notice Per-deposit metadata. `deposits[i].rootAfter` is the
  ///         depositRoot hash chain commitment *after* folding the
  ///         i-th deposit; `deposits[i].blockNumber` is the L1 block
  ///         in which the deposit was made.
  ///
  ///         `submitProof()` reads `deposits[newProcessedDepositCount
  ///         - 1].rootAfter` to anchor each proof's claimed deposit
  ///         root, with a maximality check enforcing that no later
  ///         deposit at `blockNumber <= l1RangeEnd` was skipped.
  ///
  ///         The array is append-only; no entries are ever removed.
  DepositMeta[] public deposits;

  /// @notice Live hash-chain commitment to every deposit ever made.
  ///         Equals `deposits[deposits.length - 1].rootAfter` after
  ///         the first deposit, or `bytes32(0)` before. Kept as a
  ///         distinct variable so external callers (e.g., explorers)
  ///         can query the current root without an array index. Not
  ///         used by `submitProof` — the per-proof anchor is read
  ///         out of the `deposits[]` array directly.
  bytes32 public depositRoot;

  // Note: there's no separate `depositCount` storage variable. The
  // count is `deposits.length` (auto-exposed by Solidity's array
  // length read; no extra SSTORE on deposit). The `Deposit` event's
  // `index` topic uses `deposits.length - 1` of the just-pushed entry.

  // ============================================================
  //                    VERIFIER STATE
  // ============================================================

  /// @notice The proven L2 output root (state_root +
  ///         L2_TO_L1_MESSAGE_PASSER storage_root + latest_blockhash,
  ///         hashed). Withdrawal proofs check against this via
  ///         `proven[]`. Updated on every accepted `submitProof`.
  bytes32 public currentOutputRoot;

  /// @notice The proven deposit-queue hash-chain commitment as of
  ///         the most recent accepted proof's `l1RangeEnd`. Equal to
  ///         `deposits[lastProcessedDepositCount - 1].rootAfter` (or
  ///         `bytes32(0)` if `lastProcessedDepositCount == 0`). Each
  ///         accepted proof advances this to the new
  ///         `deposits[newProcessedDepositCount - 1].rootAfter`.
  bytes32 public lastProcessedDepositRoot;

  /// @notice Number of deposits folded into
  ///         `lastProcessedDepositRoot`. Equal to the
  ///         `newProcessedDepositCount` of the most recent accepted
  ///         proof. Each accepted proof advances this monotonically.
  uint64 public lastProcessedDepositCount;

  /// @notice Highest L1 block whose deposits have been processed by
  ///         an accepted proof. The next proof must have
  ///         `l1RangeStart == lastProvenL1Block + 1`.
  uint64 public lastProvenL1Block;

  /// @notice Every output root that has ever been accepted as
  ///         "proven" by `submitProof`. Used by withdrawal-proving
  ///         to vouch for an output root the user references.
  ///         Monotonically growing — proofs are append-only.
  mapping(bytes32 => bool) public proven;

  // ============================================================
  //                   WITHDRAWAL STATE
  // ============================================================

  struct ProvenWithdrawal {
    bytes32 outputRoot;
    uint64 timestamp;
  }

  /// @notice withdrawal_hash → withdrawer → ProvenWithdrawal.
  ///         The double mapping lets multiple parties prove the same
  ///         withdrawal from different addresses.
  mapping(bytes32 => mapping(address => ProvenWithdrawal))
    public provenWithdrawals;

  /// @notice withdrawal_hash → finalized? Once a withdrawal is
  ///         finalized it cannot be replayed.
  mapping(bytes32 => bool) public finalizedWithdrawals;

  /// @notice The currently-executing withdrawal's L2 sender,
  ///         exposed during `finalizeWithdrawalTransaction` so
  ///         L1 callees can authenticate. Reset to a sentinel
  ///         outside that call.
  address public l2Sender;

  uint64 internal constant RECEIVE_DEFAULT_GAS_LIMIT = 100_000;
  address internal constant L2_TO_L1_MESSAGE_PASSER =
    0x4200000000000000000000000000000000000016;
  address internal constant DEFAULT_L2_SENDER =
    0x000000000000000000000000000000000000dEaD;

  // ============================================================
  //                         EVENTS
  // ============================================================

  /// @notice Emitted exactly once, in the constructor. Discoverability
  ///         marker for validator nodes resolving genesis from the
  ///         contract address: validator queries
  ///         `eth_getLogs(address=verifier, topics=[GenesisInitialized])`,
  ///         takes the deployment block + tx hash from the first
  ///         match, fetches the deployment transaction, ABI-decodes
  ///         the constructor's `accountsData` argument, decompresses
  ///         (zstd) and decodes (RLP) into the genesis accounts,
  ///         then derives the genesis state root and verifies it
  ///         matches `currentOutputRoot`'s seed value (which equals
  ///         `_genesisOutputRoot` at deployment time). Tampering
  ///         with the calldata fails this final check — the output
  ///         root is the cryptographic anchor, no separate hash
  ///         immutable required. The event carries no payload
  ///         because the calldata already does.
  event GenesisInitialized();

  /// @notice Emitted when a batcher posts blobs. Matches the shape
  ///         the runtime deriver's `BlobsPosted` reader expects in
  ///         `derive::verifier_events`.
  event BlobsPosted(
    address indexed batcher,
    uint64 firstBlobId,
    bytes32[] versionedHashes
  );

  /// @notice One deposit emitted per `deposit()` call. Matches the
  ///         shape `derive::deposit_events::Deposit` expects.
  event Deposit(
    uint64 indexed index,
    address indexed sender,
    uint256 value,
    address to,
    uint64 gasLimit,
    bytes data,
    bytes32 depositHash
  );

  /// @notice Emitted on every successful `submitProof`. Matches
  ///         `derive::verifier_events::ProofAccepted`.
  event ProofAccepted(
    bytes32 indexed oldOutputRoot,
    bytes32 indexed newOutputRoot,
    bytes32 newProcessedDepositRoot,
    uint64 l1RangeStart,
    uint64 l1RangeEnd,
    bytes32 l1BlockHashEnd,
    bytes32[] versionedHashes
  );

  event WithdrawalProven(
    bytes32 indexed withdrawalHash,
    address indexed from,
    address indexed to
  );

  event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success);

  // ============================================================
  //                      CONSTRUCTOR
  // ============================================================

  /// @param _chainId               L2 chain id (bound by every SNARK).
  /// @param _l1ChainId             L1 chain id this L2 settles to.
  /// @param _genesisTimestamp      L2 genesis block timestamp (Unix seconds).
  /// @param _minimumBlockGasLimit  Floor on the per-block gas limit.
  /// @param _minimumTxGasLimit     Floor on the per-tx gas-limit cap.
  /// @param _minimumCodeSize       Floor on the per-blob EIP-170 cap.
  /// @param _maximumCodeSize       Ceiling on the per-blob EIP-170 cap.
  /// @param _minimumInitcodeSize   Floor on the per-blob EIP-3860 cap.
  /// @param _maximumInitcodeSize   Ceiling on the per-blob EIP-3860 cap.
  /// @param _maximumSequencerCalldataSize
  ///                               Ceiling on the per-action `Call.calldata`
  ///                               size for sequencer-space pre-execution
  ///                               calls. Bound into every SNARK.
  /// @param _accountsData          zstd-compressed RLP of the genesis
  ///                               accounts. Not stored or hashed
  ///                               on-chain — its only purpose is to
  ///                               land in deployment-tx calldata
  ///                               so validators bootstrapping from
  ///                               the verifier address can retrieve
  ///                               it via `GenesisInitialized`. The
  ///                               cryptographic binding is via
  ///                               `_genesisOutputRoot`: tampered
  ///                               calldata produces a different
  ///                               state root, which fails the
  ///                               validator's bootstrap check.
  /// @param _quorumVerifiers       Per-zkVM verifier contracts (immutable post-deploy).
  /// @param _quorumVKeys           Verification keys, parallel to `_quorumVerifiers`.
  /// @param _quorum                Minimum distinct systems required.
  /// @param _genesisOutputRoot     L2 genesis output root (state at block 0).
  constructor(
    uint64 _chainId,
    uint64 _l1ChainId,
    uint64 _genesisTimestamp,
    uint64 _minimumBlockGasLimit,
    uint64 _minimumTxGasLimit,
    uint64 _minimumCodeSize,
    uint64 _maximumCodeSize,
    uint64 _minimumInitcodeSize,
    uint64 _maximumInitcodeSize,
    uint64 _maximumSequencerCalldataSize,
    bytes memory _accountsData,
    address[] memory _quorumVerifiers,
    bytes32[] memory _quorumVKeys,
    uint8 _quorum,
    bytes32 _genesisOutputRoot
  ) {
    require(
      _quorumVerifiers.length == _quorumVKeys.length,
      "SigilVerifier: verifier/vkey length mismatch"
    );
    require(
      _quorum > 0 && _quorum <= _quorumVerifiers.length,
      "SigilVerifier: invalid quorum"
    );
    require(
      _maximumCodeSize >= _minimumCodeSize,
      "SigilVerifier: code-size range inverted"
    );
    require(
      _maximumInitcodeSize >= _minimumInitcodeSize,
      "SigilVerifier: initcode-size range inverted"
    );
    CHAIN_ID = _chainId;
    L1_CHAIN_ID = _l1ChainId;
    GENESIS_TIMESTAMP = _genesisTimestamp;
    MINIMUM_BLOCK_GAS_LIMIT = _minimumBlockGasLimit;
    MINIMUM_TX_GAS_LIMIT = _minimumTxGasLimit;
    MINIMUM_CODE_SIZE = _minimumCodeSize;
    MAXIMUM_CODE_SIZE = _maximumCodeSize;
    MINIMUM_INITCODE_SIZE = _minimumInitcodeSize;
    MAXIMUM_INITCODE_SIZE = _maximumInitcodeSize;
    MAXIMUM_SEQUENCER_CALLDATA_SIZE = _maximumSequencerCalldataSize;
    // `_accountsData` is intentionally unused on-chain — it lives
    // in deployment calldata for off-chain validator retrieval; the
    // cryptographic binding is `_genesisOutputRoot` below.
    _accountsData;
    for (uint256 i = 0; i < _quorumVerifiers.length; i++) {
      quorumVerifiers.push(_quorumVerifiers[i]);
      quorumVKeys.push(_quorumVKeys[i]);
    }
    QUORUM = _quorum;
    currentOutputRoot = _genesisOutputRoot;
    proven[_genesisOutputRoot] = true;
    lastProvenL1Block = uint64(block.number);
    l2Sender = DEFAULT_L2_SENDER;
    // Discoverability sentinel — see `event GenesisInitialized` doc.
    emit GenesisInitialized();
  }

  // ============================================================
  //                    BLOB REGISTRY API
  // ============================================================

  /// @notice Register every blob attached to the calling transaction.
  ///         Permissionless: anyone can post blob-carrying transactions
  ///         invoking this. Pulls versioned hashes from `BLOBHASH(i)`
  ///         starting at i=0 until `BLOBHASH(i) == bytes32(0)`, assigns
  ///         each a monotonic id, and emits `BlobsPosted`.
  function postBlobs() external {
    uint64 firstId = nextBlobId;
    uint256 i = 0;
    bytes32[] memory hashes;
    uint256 count = 0;

    // First pass: count blobs.
    while (true) {
      bytes32 vh;
      assembly { vh := blobhash(i) }
      if (vh == bytes32(0)) break;
      i++;
      count++;
    }
    require(count > 0, "SigilVerifier: no blobs in transaction");

    // Second pass: collect into the array (BLOBHASH is cheap).
    hashes = new bytes32[](count);
    for (uint256 j = 0; j < count; j++) {
      bytes32 vh;
      assembly { vh := blobhash(j) }
      hashes[j] = vh;
      blobVersionedHashes[nextBlobId] = vh;
      unchecked { nextBlobId++; }
    }

    emit BlobsPosted(msg.sender, firstId, hashes);
  }

  // ============================================================
  //                    DEPOSIT QUEUE API
  // ============================================================

  /// @notice Enqueue a force-included L2 transaction. The deposit's
  ///         `block.number` is bound into the leaf hash so the
  ///         in-zkVM partition rule "deposit at L1 inclusion ≤ K is
  ///         processed by the first L2 block at l1_origin ≥ K" is
  ///         cryptographically enforceable without per-deposit MPT
  ///         proofs.
  ///
  /// @param _to       L2 destination address. `address(0)` is the
  ///                  CREATE convention.
  /// @param _gasLimit L2 gas budget for this deposit's execution.
  /// @param _data     Calldata for the L2 deposit transaction.
  function deposit(
    address _to,
    uint64 _gasLimit,
    bytes calldata _data
  ) external payable {
    require(_data.length <= type(uint32).max, "SigilVerifier: data too long");

    // abi.encodePacked layout matches `derive::deposits::deposit_hash`
    // and the in-zkVM hash chain reconstruction byte-for-byte.
    // 20 + 32 + 8 + 20 + 8 + 4 + N
    bytes32 leaf = keccak256(
      abi.encodePacked(
        msg.sender,
        msg.value,
        uint64(block.number),
        _to,
        _gasLimit,
        uint32(_data.length),
        _data
      )
    );
    bytes32 newRoot = keccak256(abi.encodePacked(depositRoot, leaf));
    depositRoot = newRoot;
    deposits.push(DepositMeta({
      blockNumber: uint64(block.number),
      rootAfter: newRoot
    }));
    emit Deposit(
      uint64(deposits.length - 1),
      msg.sender,
      msg.value,
      _to,
      _gasLimit,
      _data,
      leaf
    );
  }

  // ============================================================
  //                     PROOF SUBMISSION
  // ============================================================

  /// @notice Public-input tuple committed by every accepted SNARK.
  ///         ABI-encoded form is what each per-zkVM verifier
  ///         consumes as `_publicValues` in
  ///         [`ISP1Verifier.verifyProof`]. The Rust prover-program
  ///         emits the equivalent encoding via `alloy_sol_types`.
  struct PublicInputs {
    bytes32 oldOutputRoot;
    bytes32 newOutputRoot;
    bytes32 lastProcessedDepositRoot;
    bytes32 newProcessedDepositRoot;

    /// @dev Number of deposits already folded into
    ///      `lastProcessedDepositRoot` (i.e., processed by prior
    ///      proofs). Validated against `this.lastProcessedDepositCount`.
    uint64 lastProcessedDepositCount;

    /// @dev Number of deposits the SNARK folded into
    ///      `newProcessedDepositRoot`. Validated against the
    ///      `deposits[]` array: the indexed deposit must lie within
    ///      `l1RangeEnd` and the next-indexed deposit (if any) must
    ///      lie strictly past it (maximality).
    uint64 newProcessedDepositCount;

    uint64 l1RangeStart;
    uint64 l1RangeEnd;
    bytes32 l1BlockHashEnd;
    uint64 chainId;
    uint64 l1ChainId;
    uint64 genesisTimestamp;
    uint64 minimumBlockGasLimit;
    uint64 minimumTxGasLimit;
    uint64 minimumCodeSize;
    uint64 maximumCodeSize;
    uint64 minimumInitcodeSize;
    uint64 maximumInitcodeSize;
    uint64 maximumSequencerCalldataSize;
    bytes32[] versionedHashes;

    /// @dev Flattened (z_i, y_i) Fiat-Shamir / barycentric pairs:
    ///      length = 2 * versionedHashes.length, layout
    ///      `[z_0, y_0, z_1, y_1, ...]`. Each element is a 32-byte
    ///      big-endian BLS12-381 scalar.
    bytes32[] zEvaluations;
  }

  /// @notice Advance state by submitting a multi-zkVM quorum of
  ///         proofs over the same `PublicInputs` tuple. Steps:
  ///
  ///         1. Validate `oldOutputRoot == currentOutputRoot` (race resolution).
  ///         2. Validate `lastProcessedDepositRoot == this.lastProcessedDepositRoot`.
  ///         3. Validate `l1RangeStart == lastProvenL1Block + 1` (no skipping).
  ///         4. Validate `chainId / minimumBlockGasLimit / minimumTxGasLimit` against contract's immutables (Genesis-on-contract).
  ///         5. Validate `l1BlockHashEnd` against on-chain `BLOCKHASH` / EIP-2935.
  ///         6. Per blob: EIP-4844 point-evaluation precompile with
  ///            (versioned_hash, z, y, commitment, kzg_proof).
  ///         7. Verify `≥ QUORUM` proofs from distinct zkVM systems.
  ///         8. Update state, emit `ProofAccepted`.
  ///
  /// @param pv          Public inputs the SNARK committed to.
  /// @param commitments Per-blob KZG commitments (48 bytes each, hashes to vh).
  /// @param kzgProofs   Per-blob KZG witness proofs (48 bytes each).
  /// @param systems     Per-proof zkVM system index (into `quorumVerifiers`).
  /// @param proofs      Per-proof SNARK bytes, parallel to `systems`.
  function submitProof(
    PublicInputs calldata pv,
    bytes[] calldata commitments,
    bytes[] calldata kzgProofs,
    uint8[] calldata systems,
    bytes[] calldata proofs
  ) external {

    // --- 1-4. State + Genesis checks. ---
    require(
      pv.oldOutputRoot == currentOutputRoot,
      "SigilVerifier: stale oldOutputRoot"
    );
    require(
      pv.lastProcessedDepositRoot == lastProcessedDepositRoot,
      "SigilVerifier: stale lastProcessedDepositRoot"
    );
    require(
      pv.lastProcessedDepositCount == lastProcessedDepositCount,
      "SigilVerifier: stale lastProcessedDepositCount"
    );
    require(
      pv.l1RangeStart == lastProvenL1Block + 1,
      "SigilVerifier: non-contiguous l1Range"
    );
    require(pv.l1RangeEnd >= pv.l1RangeStart, "SigilVerifier: empty range");

    // --- 4b. Deposit hash-chain anchor via SLOAD (no L1 state walk). ---
    //
    // Validates `pv.newProcessedDepositRoot` against the on-chain
    // per-deposit snapshot at index `pv.newProcessedDepositCount - 1`,
    // with maximality enforcement: every deposit at `blockNumber <=
    // l1RangeEnd` MUST have been folded. Skipping a deposit that L1
    // included would otherwise let funds be permanently locked.
    require(
      pv.newProcessedDepositCount >= pv.lastProcessedDepositCount,
      "SigilVerifier: newProcessedDepositCount regressed"
    );
    require(
      pv.newProcessedDepositCount <= deposits.length,
      "SigilVerifier: newProcessedDepositCount past deposits.length"
    );
    if (pv.newProcessedDepositCount == 0) {
      require(
        pv.newProcessedDepositRoot == bytes32(0),
        "SigilVerifier: newProcessedDepositRoot must be zero before any deposit"
      );
    } else {
      DepositMeta memory anchor = deposits[pv.newProcessedDepositCount - 1];
      require(
        anchor.blockNumber <= pv.l1RangeEnd,
        "SigilVerifier: anchor deposit past l1RangeEnd"
      );
      require(
        pv.newProcessedDepositRoot == anchor.rootAfter,
        "SigilVerifier: newProcessedDepositRoot mismatch with snapshot"
      );
      // Maximality: the next deposit (if any) must lie strictly past
      // l1RangeEnd, otherwise the prover skipped a deposit it should
      // have folded.
      if (pv.newProcessedDepositCount < deposits.length) {
        require(
          deposits[pv.newProcessedDepositCount].blockNumber > pv.l1RangeEnd,
          "SigilVerifier: skipped deposit at or before l1RangeEnd"
        );
      }
    }
    require(pv.chainId == CHAIN_ID, "SigilVerifier: chainId mismatch");
    require(
      pv.l1ChainId == L1_CHAIN_ID,
      "SigilVerifier: l1ChainId mismatch"
    );
    require(
      pv.genesisTimestamp == GENESIS_TIMESTAMP,
      "SigilVerifier: genesisTimestamp mismatch"
    );
    require(
      pv.minimumBlockGasLimit == MINIMUM_BLOCK_GAS_LIMIT,
      "SigilVerifier: minimumBlockGasLimit mismatch"
    );
    require(
      pv.minimumTxGasLimit == MINIMUM_TX_GAS_LIMIT,
      "SigilVerifier: minimumTxGasLimit mismatch"
    );
    require(
      pv.minimumCodeSize == MINIMUM_CODE_SIZE,
      "SigilVerifier: minimumCodeSize mismatch"
    );
    require(
      pv.maximumCodeSize == MAXIMUM_CODE_SIZE,
      "SigilVerifier: maximumCodeSize mismatch"
    );
    require(
      pv.minimumInitcodeSize == MINIMUM_INITCODE_SIZE,
      "SigilVerifier: minimumInitcodeSize mismatch"
    );
    require(
      pv.maximumInitcodeSize == MAXIMUM_INITCODE_SIZE,
      "SigilVerifier: maximumInitcodeSize mismatch"
    );
    require(
      pv.maximumSequencerCalldataSize == MAXIMUM_SEQUENCER_CALLDATA_SIZE,
      "SigilVerifier: maximumSequencerCalldataSize mismatch"
    );

    // --- 5. L1 anchor verification. ---
    require(
      _l1BlockHashAt(pv.l1RangeEnd) == pv.l1BlockHashEnd,
      "SigilVerifier: L1 anchor mismatch"
    );

    // --- 6. Per-blob KZG point-evaluation. ---
    require(
      commitments.length == pv.versionedHashes.length,
      "SigilVerifier: commitments length mismatch"
    );
    require(
      kzgProofs.length == pv.versionedHashes.length,
      "SigilVerifier: kzgProofs length mismatch"
    );
    require(
      pv.zEvaluations.length == 2 * pv.versionedHashes.length,
      "SigilVerifier: zEvaluations length mismatch"
    );
    for (uint256 i = 0; i < pv.versionedHashes.length; i++) {
      _pointEvaluation(
        pv.versionedHashes[i],
        pv.zEvaluations[2 * i],
        pv.zEvaluations[2 * i + 1],
        commitments[i],
        kzgProofs[i]
      );
    }

    // --- 7. Multi-zkVM quorum verification. ---
    require(
      systems.length == proofs.length,
      "SigilVerifier: systems/proofs length mismatch"
    );
    require(systems.length >= QUORUM, "SigilVerifier: insufficient proofs");
    bytes memory pvBytes = abi.encode(pv);
    bool[] memory seen = new bool[](quorumVerifiers.length);
    uint8 distinct = 0;
    for (uint256 i = 0; i < systems.length; i++) {
      uint8 s = systems[i];
      require(
        s < quorumVerifiers.length,
        "SigilVerifier: invalid system index"
      );
      require(!seen[s], "SigilVerifier: duplicate system");
      seen[s] = true;
      ISP1Verifier(quorumVerifiers[s]).verifyProof(
        quorumVKeys[s],
        pvBytes,
        proofs[i]
      );
      unchecked { distinct++; }
    }
    require(distinct >= QUORUM, "SigilVerifier: insufficient distinct systems");

    // --- 8. Advance state, emit ProofAccepted. ---
    bytes32 oldOutputRoot = currentOutputRoot;
    currentOutputRoot = pv.newOutputRoot;
    lastProcessedDepositRoot = pv.newProcessedDepositRoot;
    lastProcessedDepositCount = pv.newProcessedDepositCount;
    lastProvenL1Block = pv.l1RangeEnd;
    proven[pv.newOutputRoot] = true;

    emit ProofAccepted(
      oldOutputRoot,
      pv.newOutputRoot,
      pv.newProcessedDepositRoot,
      pv.l1RangeStart,
      pv.l1RangeEnd,
      pv.l1BlockHashEnd,
      pv.versionedHashes
    );
  }

  // ============================================================
  //                  WITHDRAWAL PROVING / FINALIZATION
  // ============================================================

  /// @notice Default `receive` triggers a deposit with zero data.
  receive() external payable {
    this.deposit{value: msg.value}(
      msg.sender,
      RECEIVE_DEFAULT_GAS_LIMIT,
      ""
    );
  }

  /// @notice Prove an L2→L1 withdrawal against a proven L2 output root.
  function proveWithdrawalTransaction(
    Types.WithdrawalTransaction memory _tx,
    Types.OutputRootProof calldata _outputRootProof,
    bytes[] calldata _withdrawalProof
  ) external {
    bytes32 root = Hashing.hashOutputRootProof(_outputRootProof);
    require(proven[root], "SigilVerifier: output root not proven");

    bytes32 withdrawalHash = Hashing.hashWithdrawal(_tx);
    bytes32 storageKey = keccak256(abi.encode(withdrawalHash, uint256(0)));
    require(
      SecureMerkleTrie.verifyInclusionProof(
        abi.encode(storageKey),
        hex"01",
        _withdrawalProof,
        _outputRootProof.messagePasserStorageRoot
      ),
      "SigilVerifier: invalid withdrawal proof"
    );

    provenWithdrawals[withdrawalHash][msg.sender] = ProvenWithdrawal({
      outputRoot: root,
      timestamp: uint64(block.timestamp)
    });
    emit WithdrawalProven(withdrawalHash, msg.sender, _tx.target);
  }

  /// @notice Finalize a previously-proven withdrawal, executing the
  ///         L1-side call. Re-checks that the output root the
  ///         withdrawal was proven against is still in `proven[]` —
  ///         once a root is added it stays, so this is informational.
  function finalizeWithdrawalTransaction(
    Types.WithdrawalTransaction memory _tx
  ) external {
    bytes32 withdrawalHash = Hashing.hashWithdrawal(_tx);
    ProvenWithdrawal memory pw = provenWithdrawals[withdrawalHash][msg.sender];
    require(pw.timestamp > 0, "SigilVerifier: withdrawal not proven");
    require(
      !finalizedWithdrawals[withdrawalHash],
      "SigilVerifier: already finalized"
    );
    require(
      proven[pw.outputRoot],
      "SigilVerifier: output root invalidated"
    );

    finalizedWithdrawals[withdrawalHash] = true;
    l2Sender = _tx.sender;
    bool ok = SafeCall.callWithMinGas(
      _tx.target,
      _tx.gasLimit,
      _tx.value,
      _tx.data
    );
    l2Sender = DEFAULT_L2_SENDER;
    emit WithdrawalFinalized(withdrawalHash, ok);
  }

  // ============================================================
  //                       INTERNAL HELPERS
  // ============================================================

  /// @notice Looks up the L1 block hash at `_blockNum`. Prefers the
  ///         `BLOCKHASH` opcode (cheap, last 256 blocks); falls back
  ///         to the EIP-2935 history contract for the remainder of
  ///         the 8191-block window. Out-of-window queries return 0
  ///         and the caller's `require` rejects.
  function _l1BlockHashAt(uint64 _blockNum) internal view returns (bytes32) {
    uint256 current = block.number;
    if (_blockNum >= current) return bytes32(0);
    if (current - _blockNum <= 256) {
      return blockhash(_blockNum);
    }
    (bool ok, bytes memory ret) = BLOCK_HASH_HISTORY.staticcall(
      abi.encode(_blockNum)
    );
    if (!ok || ret.length != 32) return bytes32(0);
    return abi.decode(ret, (bytes32));
  }

  /// @notice EIP-4844 point-evaluation precompile address.
  address internal constant POINT_EVALUATION_PRECOMPILE = address(0x0A);

  /// @notice EIP-4844 point-evaluation. Verifies that the polynomial
  ///         committed by `commitment` (whose
  ///         `kzg_to_versioned_hash` equals `vh`) opens at `z` to
  ///         `y` via the supplied KZG witness `kzgProof`. Reverts
  ///         on failure.
  function _pointEvaluation(
    bytes32 vh,
    bytes32 z,
    bytes32 y,
    bytes memory commitment,
    bytes memory kzgProof
  ) internal view {
    require(
      commitment.length == 48,
      "SigilVerifier: commitment must be 48 bytes"
    );
    require(
      kzgProof.length == 48,
      "SigilVerifier: kzgProof must be 48 bytes"
    );
    bytes memory input =
      abi.encodePacked(vh, z, y, commitment, kzgProof);
    (bool ok, ) = POINT_EVALUATION_PRECOMPILE.staticcall(input);
    require(ok, "SigilVerifier: point evaluation failed");
  }

  function version() public pure returns (string memory) {
    return "1.0.0";
  }
}

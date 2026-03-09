// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title SystemConfig
/// @notice Manages configuration of the L2 rollup on L1. The rollup node reads configuration
///         updates from events emitted by this contract. Simplified for testnet deployment.
contract SystemConfig {
    /// @notice Enum representing different types of updates.
    enum UpdateType {
        BATCHER,
        FEE_SCALARS,
        GAS_LIMIT,
        UNSAFE_BLOCK_SIGNER,
        EIP_1559_PARAMS,
        OPERATOR_FEE_PARAMS,
        MIN_BASE_FEE,
        DA_FOOTPRINT_GAS_SCALAR
    }

    /// @notice Emitted when configuration is updated.
    event ConfigUpdate(uint256 indexed version, UpdateType indexed updateType, bytes data);

    /// @notice The owner of this contract.
    address public owner;

    /// @notice The overhead value applied to the L1 portion of the transaction fee.
    uint256 public overhead;

    /// @notice The scalar value applied to the L1 portion of the transaction fee.
    uint256 public scalar;

    /// @notice The address of the batcher.
    bytes32 public batcherHash;

    /// @notice The L2 block gas limit.
    uint64 public gasLimit;

    /// @notice The base fee scalar for Ecotone.
    uint32 public baseFeeScalar;

    /// @notice The blob base fee scalar for Ecotone.
    uint32 public blobBaseFeeScalar;

    /// @notice The unsafe block signer address.
    /// @dev Stored at deterministic slot for decoupled storage layout.
    bytes32 public constant UNSAFE_BLOCK_SIGNER_SLOT = keccak256("systemconfig.unsafeblocksigner");

    /// @notice Storage slot for the batch inbox address.
    bytes32 public constant BATCH_INBOX_SLOT = bytes32(uint256(keccak256("systemconfig.batchinbox")) - 1);

    /// @notice Storage slot for the start block.
    bytes32 public constant START_BLOCK_SLOT = bytes32(uint256(keccak256("systemconfig.startBlock")) - 1);

    modifier onlyOwner() {
        require(msg.sender == owner, "SystemConfig: caller is not the owner");
        _;
    }

    /// @notice Initialize the SystemConfig.
    /// @param _owner           Owner address.
    /// @param _overhead        L1 fee overhead.
    /// @param _scalar          L1 fee scalar.
    /// @param _batcherHash     Hash of the batcher address.
    /// @param _gasLimit        L2 gas limit.
    /// @param _unsafeBlockSigner Address of the unsafe block signer.
    /// @param _batchInbox      Batch inbox address.
    function initialize(
        address _owner,
        uint256 _overhead,
        uint256 _scalar,
        bytes32 _batcherHash,
        uint64 _gasLimit,
        address _unsafeBlockSigner,
        address _batchInbox
    ) external {
        require(owner == address(0), "SystemConfig: already initialized");
        owner = _owner;
        overhead = _overhead;
        scalar = _scalar;
        batcherHash = _batcherHash;
        gasLimit = _gasLimit;

        // Store the unsafe block signer at the deterministic slot.
        bytes32 slot = UNSAFE_BLOCK_SIGNER_SLOT;
        assembly { sstore(slot, _unsafeBlockSigner) }

        // Store the batch inbox at the deterministic slot.
        bytes32 batchInboxSlot = BATCH_INBOX_SLOT;
        assembly { sstore(batchInboxSlot, _batchInbox) }

        // Store the start block.
        bytes32 startBlockSlot = START_BLOCK_SLOT;
        assembly { sstore(startBlockSlot, number()) }

        emit ConfigUpdate(0, UpdateType.BATCHER, abi.encode(batcherHash));
        emit ConfigUpdate(0, UpdateType.FEE_SCALARS, abi.encode(overhead, scalar));
        emit ConfigUpdate(0, UpdateType.GAS_LIMIT, abi.encode(gasLimit));
        emit ConfigUpdate(0, UpdateType.UNSAFE_BLOCK_SIGNER, abi.encode(_unsafeBlockSigner));
    }

    /// @notice Update the batcher address.
    function setBatcherHash(bytes32 _batcherHash) external onlyOwner {
        batcherHash = _batcherHash;
        emit ConfigUpdate(0, UpdateType.BATCHER, abi.encode(_batcherHash));
    }

    /// @notice Update the L2 gas limit.
    function setGasLimit(uint64 _gasLimit) external onlyOwner {
        require(_gasLimit >= 1_000_000, "SystemConfig: gas limit too low");
        gasLimit = _gasLimit;
        emit ConfigUpdate(0, UpdateType.GAS_LIMIT, abi.encode(_gasLimit));
    }

    /// @notice Update the unsafe block signer.
    function setUnsafeBlockSigner(address _unsafeBlockSigner) external onlyOwner {
        bytes32 slot = UNSAFE_BLOCK_SIGNER_SLOT;
        assembly { sstore(slot, _unsafeBlockSigner) }
        emit ConfigUpdate(0, UpdateType.UNSAFE_BLOCK_SIGNER, abi.encode(_unsafeBlockSigner));
    }

    /// @notice Returns the unsafe block signer address.
    function unsafeBlockSigner() external view returns (address signer_) {
        bytes32 slot = UNSAFE_BLOCK_SIGNER_SLOT;
        assembly { signer_ := sload(slot) }
    }

    /// @notice Returns the batch inbox address.
    function batchInbox() external view returns (address inbox_) {
        bytes32 slot = BATCH_INBOX_SLOT;
        assembly { inbox_ := sload(slot) }
    }

    /// @notice Returns the start block.
    function startBlock() external view returns (uint256 startBlock_) {
        bytes32 slot = START_BLOCK_SLOT;
        assembly { startBlock_ := sload(slot) }
    }

    /// @notice The minimum gas limit for the system.
    function minimumGasLimit() public pure returns (uint64) {
        return 1_000_000;
    }

    function version() public pure returns (string memory) {
        return "2.6.0";
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Types } from "src/l2/lib/Types.sol";
import { Hashing } from "src/l2/lib/Hashing.sol";
import { SafeCall } from "src/l2/lib/SafeCall.sol";
import { SecureMerkleTrie } from "src/l2/lib/SecureMerkleTrie.sol";

/// @title KosherPortal
/// @notice Simplified portal for deposits and withdrawals, using KosherVerifier as the
///         source of truth for proven output roots. No dispute games or challenge windows.
contract KosherPortal {
    /// @notice Address of the KosherVerifier.
    address public immutable VERIFIER;

    struct ProvenWithdrawal {
        bytes32 outputRoot;
        uint64 timestamp;
    }

    mapping(bytes32 => mapping(address => ProvenWithdrawal)) public provenWithdrawals;
    mapping(bytes32 => bool) public finalizedWithdrawals;

    event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to);
    event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success);
    event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData);

    uint64 internal constant RECEIVE_DEFAULT_GAS_LIMIT = 100_000;
    address internal constant L2_TO_L1_MESSAGE_PASSER = 0x4200000000000000000000000000000000000016;
    address public l2Sender;
    address internal constant DEFAULT_L2_SENDER = 0x000000000000000000000000000000000000dEaD;

    constructor(address _verifier) {
        VERIFIER = _verifier;
        l2Sender = DEFAULT_L2_SENDER;
    }

    receive() external payable {
        depositTransaction(msg.sender, msg.value, RECEIVE_DEFAULT_GAS_LIMIT, false, bytes(""));
    }

    /// @notice Creates a deposit transaction.
    function depositTransaction(
        address _to, uint256 _value, uint64 _gasLimit, bool _isCreation, bytes memory _data
    ) public payable {
        bytes memory opaqueData = abi.encodePacked(msg.value, _value, _gasLimit, _isCreation, _data);
        emit TransactionDeposited(msg.sender, _to, 0, opaqueData);
    }

    /// @notice Proves a withdrawal transaction against a proven output root.
    function proveWithdrawalTransaction(
        Types.WithdrawalTransaction memory _tx,
        Types.OutputRootProof calldata _outputRootProof,
        bytes[] calldata _withdrawalProof
    ) external {
        bytes32 root = Hashing.hashOutputRootProof(_outputRootProof);
        // Check that KosherVerifier has proven this root.
        (bool success, bytes memory data) = VERIFIER.staticcall(
            abi.encodeWithSignature("proven(bytes32)", root)
        );
        require(success && abi.decode(data, (bool)), "KosherPortal: output root not proven");

        bytes32 withdrawalHash = Hashing.hashWithdrawal(_tx);
        bytes32 storageKey = keccak256(abi.encode(withdrawalHash, uint256(0)));

        require(
            SecureMerkleTrie.verifyInclusionProof(
                abi.encode(storageKey), hex"01", _withdrawalProof, _outputRootProof.messagePasserStorageRoot
            ),
            "KosherPortal: invalid withdrawal proof"
        );

        provenWithdrawals[withdrawalHash][msg.sender] = ProvenWithdrawal({
            outputRoot: root,
            timestamp: uint64(block.timestamp)
        });
        emit WithdrawalProven(withdrawalHash, msg.sender, _tx.target);
    }

    /// @notice Finalizes a proven withdrawal transaction.
    function finalizeWithdrawalTransaction(Types.WithdrawalTransaction memory _tx) external {
        bytes32 withdrawalHash = Hashing.hashWithdrawal(_tx);
        ProvenWithdrawal memory pw = provenWithdrawals[withdrawalHash][msg.sender];
        require(pw.timestamp > 0, "KosherPortal: withdrawal not proven");
        require(!finalizedWithdrawals[withdrawalHash], "KosherPortal: already finalized");

        // Check that the output root is still proven.
        (bool success, bytes memory data) = VERIFIER.staticcall(
            abi.encodeWithSignature("proven(bytes32)", pw.outputRoot)
        );
        require(success && abi.decode(data, (bool)), "KosherPortal: output root invalidated");

        finalizedWithdrawals[withdrawalHash] = true;
        l2Sender = _tx.sender;
        bool callSuccess = SafeCall.callWithMinGas(_tx.target, _tx.gasLimit, _tx.value, _tx.data);
        l2Sender = DEFAULT_L2_SENDER;
        emit WithdrawalFinalized(withdrawalHash, callSuccess);
    }

    function version() public pure returns (string memory) { return "1.0.0"; }
}

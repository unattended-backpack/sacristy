// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { ISP1Verifier } from "src/l2/verifier/ISP1Verifier.sol";

/// @notice Public values for the aggregation proof.
struct AggregationOutputs {
    bytes32 l1Head;
    bytes32 l2PreRoot;
    bytes32 claimRoot;
    uint256 claimBlockNum;
    bytes32 rollupConfigHash;
    bytes32 rangeVkeyCommitment;
}

/// @title KosherVerifier
/// @notice Verifies ZK proofs to advance the rollup state. The only source of truth
///         for the rollup's proven state — no dispute games, no challenge windows.
contract KosherVerifier {
    ISP1Verifier public immutable SP1_VERIFIER;
    bytes32 public immutable AGGREGATION_VKEY;
    bytes32 public immutable ROLLUP_CONFIG_HASH;
    bytes32 public immutable RANGE_VKEY_COMMITMENT;

    bytes32 public outputRoot;
    uint256 public provenBlockNum;
    mapping(bytes32 => bool) public proven;

    event StateAdvanced(bytes32 indexed outputRoot, uint256 indexed blockNum);

    constructor(
        ISP1Verifier _sp1Verifier,
        bytes32 _aggregationVkey,
        bytes32 _rollupConfigHash,
        bytes32 _rangeVkeyCommitment,
        bytes32 _genesisOutputRoot,
        uint256 _genesisBlockNum
    ) {
        SP1_VERIFIER = _sp1Verifier;
        AGGREGATION_VKEY = _aggregationVkey;
        ROLLUP_CONFIG_HASH = _rollupConfigHash;
        RANGE_VKEY_COMMITMENT = _rangeVkeyCommitment;
        outputRoot = _genesisOutputRoot;
        provenBlockNum = _genesisBlockNum;
        proven[_genesisOutputRoot] = true;
    }

    function prove(
        bytes32 _claimRoot,
        uint256 _claimBlockNum,
        bytes32 _l1Head,
        bytes calldata _proofBytes
    ) external {
        require(_claimBlockNum > provenBlockNum, "must advance");

        AggregationOutputs memory outputs = AggregationOutputs({
            l1Head: _l1Head,
            l2PreRoot: outputRoot,
            claimRoot: _claimRoot,
            claimBlockNum: _claimBlockNum,
            rollupConfigHash: ROLLUP_CONFIG_HASH,
            rangeVkeyCommitment: RANGE_VKEY_COMMITMENT
        });

        SP1_VERIFIER.verifyProof(AGGREGATION_VKEY, abi.encode(outputs), _proofBytes);

        outputRoot = _claimRoot;
        provenBlockNum = _claimBlockNum;
        proven[_claimRoot] = true;

        emit StateAdvanced(_claimRoot, _claimBlockNum);
    }

    function version() public pure returns (string memory) { return "1.0.0"; }
}

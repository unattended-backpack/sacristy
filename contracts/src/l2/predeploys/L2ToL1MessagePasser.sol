// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Types } from "src/l2/lib/Types.sol";
import { Hashing } from "src/l2/lib/Hashing.sol";
import { Encoding } from "src/l2/lib/Encoding.sol";
import { Burn } from "src/l2/lib/Burn.sol";

/// @custom:predeploy 0x4200000000000000000000000000000000000016
/// @title L2ToL1MessagePasser
/// @notice The L2ToL1MessagePasser is a dedicated contract where messages being sent from
///         L2 to L1 can be stored. The storage root of this contract is pulled up to the top level
///         of the L2 output to reduce the cost of proving the existence of sent messages.
contract L2ToL1MessagePasser {
    uint256 internal constant RECEIVE_DEFAULT_GAS_LIMIT = 100_000;
    uint16 public constant MESSAGE_VERSION = 1;

    /// @notice Includes the message hashes for all withdrawals.
    mapping(bytes32 => bool) public sentMessages;

    /// @notice A unique value hashed with each withdrawal.
    uint240 internal msgNonce;

    event MessagePassed(
        uint256 indexed nonce, address indexed sender, address indexed target,
        uint256 value, uint256 gasLimit, bytes data, bytes32 withdrawalHash
    );

    event WithdrawerBalanceBurnt(uint256 indexed amount);

    function version() public pure virtual returns (string memory) {
        return "1.2.0";
    }

    receive() external payable {
        initiateWithdrawal(msg.sender, RECEIVE_DEFAULT_GAS_LIMIT, bytes(""));
    }

    function burn() external {
        uint256 balance = address(this).balance;
        Burn.eth(balance);
        emit WithdrawerBalanceBurnt(balance);
    }

    function initiateWithdrawal(address _target, uint256 _gasLimit, bytes memory _data) public payable virtual {
        bytes32 withdrawalHash = Hashing.hashWithdrawal(
            Types.WithdrawalTransaction({
                nonce: messageNonce(),
                sender: msg.sender,
                target: _target,
                value: msg.value,
                gasLimit: _gasLimit,
                data: _data
            })
        );
        sentMessages[withdrawalHash] = true;
        emit MessagePassed(messageNonce(), msg.sender, _target, msg.value, _gasLimit, _data, withdrawalHash);
        unchecked { ++msgNonce; }
    }

    function messageNonce() public view returns (uint256) {
        return Encoding.encodeVersionedNonce(msgNonce, MESSAGE_VERSION);
    }
}

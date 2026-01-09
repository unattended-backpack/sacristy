// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Multicall Delegate Interface
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A multicall contract for EIP-7702 delegation. EOAs can delegate to this
  contract to gain batched call capability. When an EOA authorizes this contract
  via 7702, calls to the EOA execute this code with `address(this) = EOA`, thus
  preserving `msg.sender` semantics for all subcalls.

  @custom:date December 22nd, 2025.
*/
interface IMulticallDelegate {

  /**
    This struct encodes information about each call an account is making.

    @param value The Ether value of the call.
    @param target The target account of the call.
    @param data The call's data.
  */
  struct Call {
    uint256 value;
    address target;
    bytes data;
  }

  /**
    Execute multiple calls in a single transaction. Only the delegating EOA can
    call this (`msg.sender` must equal `address(this)`).

    @param _calls The array of calls to execute.

    @return _ The array of return data from each call.
  */
  function multicall (
    Call[] calldata _calls
  ) external returns (bytes[] memory);

  /**
    Execute multiple calls, allowing failures. Only the delegating EOA can call
    this (`msg.sender` must equal `address(this)`).

    @param _calls The array of calls to execute.

    @return _ A tuple of arrays, with the first array denoting the success of
      each call and the second array the return data from each call.
  */
  function tryMulticall (
    Call[] calldata _calls
  ) external returns (bool[] memory, bytes[] memory);
}


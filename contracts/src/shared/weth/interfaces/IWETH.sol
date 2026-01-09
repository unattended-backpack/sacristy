// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Wrapped Ether Interface
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  This is an implementation of a wrapped Ether contract for bringing ERC-20
  behavior to Ether.

  @custom:date January 2nd, 2026.
*/
interface IWETH {

  /**
    Return the name of the token.

    @return _ The name of the token.
  */
  function name () external view returns (string memory);

  /**
    Returns the symbol of the token.

    @return _ The symbol of the token.
  */
  function symbol () external view returns (string memory);

  /**
    Deposits `msg.value` Ether from the caller and mints an equal amount of WETH
    to the caller. This is also called by the underlying `receive` function.
  */
  function deposit () external payable;
  
  /**
    Burns `_amount` WETH of the caller and sends `_amount` Ether to the caller.

    @param _amount The amount of WETH to burn and withdraw Ether for.
  */
  function withdraw (
    uint256 _amount
  ) external;
}

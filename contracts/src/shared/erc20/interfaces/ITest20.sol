// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Test20 Interface
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  The interface for the Test20 ERC-20 contract, a test token with a public
  faucet mint function.

  @custom:date January 4th, 2026.
*/
interface ITest20 {

  /**
    Return the name of the token.

    @return _ The name of the token.
  */
  function name () external pure returns (string memory);

  /**
    Returns the symbol of the token.

    @return _ The symbol of the token.
  */
  function symbol () external pure returns (string memory);

  /**
    Mint `_amount` tokens to the caller. This is a faucet function for testing.

    @param _amount The amount of tokens to mint.
  */
  function mint (
    uint256 _amount
  ) external;
}


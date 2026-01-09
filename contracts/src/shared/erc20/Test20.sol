// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { ITest20 } from "./interfaces/ITest20.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title A test ERC-20 token.
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A test ERC-20 token with a public faucet mint function. Anyone can mint any
  amount of tokens to themselves for testing purposes.

  @custom:date January 4th, 2026.
*/
contract Test20 is
  ITest20,
  ERC20 {

  /**
    Return the name of the token.

    @return _ The name of the token.
  */
  function name () public pure override(ITest20, ERC20) returns (
    string memory
  ) {
    return "Test 20";
  }

  /**
    Returns the symbol of the token.

    @return _ The symbol of the token.
  */
  function symbol () public pure override(ITest20, ERC20) returns (
    string memory
  ) {
    return "TEST20";
  }

  /**
    Mint `_amount` tokens to the caller. This is a faucet function for testing.

    @param _amount The amount of tokens to mint.
  */
  function mint (
    uint256 _amount
  ) external {
    _mint(msg.sender, _amount);
  }
}


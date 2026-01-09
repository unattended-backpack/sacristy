// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Test1155 Interface
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  The interface for the Test1155 ERC-1155 contract, a test multi-token with a
  public faucet mint function. Each minted token displays custom text as fully
  on-chain SVG art with black text on a white background.

  @custom:date January 5th, 2026.
*/
interface ITest1155 {

  /**
    Returns the next token ID to be minted.

    @return _ The next token ID.
  */
  function nextId () external view returns (uint256);

  /**
    Returns the text stored for a given token ID.

    @param _id The token ID to get the text for.

    @return _ The text stored for this token.
  */
  function text (
    uint256 _id
  ) external view returns (string memory);

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
    Returns the URI for a given token ID. The URI is a base64-encoded JSON
    metadata object containing an on-chain SVG image with the token's text
    displayed as black text centered on a white background.

    @param _id The token ID to get the URI for.

    @return _ The token URI as a base64-encoded data URI.
  */
  function uri (
    uint256 _id
  ) external view returns (string memory);

  /**
    Mint `_amount` new tokens to the caller with the given `_text` displayed on
    them. This is a faucet function for testing. The token ID is
    auto-incremented.

    @param _text The text to display on the tokens.
    @param _amount The number of tokens to mint.

    @return _ The token ID of the newly minted tokens.
  */
  function mint (
    string calldata _text,
    uint256 _amount
  ) external returns (uint256);
}


// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Test721 Interface
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  The interface for the Test721 ERC-721 contract, a test NFT with a public
  faucet mint function. Each minted NFT displays custom text as fully on-chain
  SVG art.

  @custom:date January 5th, 2026.
*/
interface ITest721 {

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
    Returns the token URI for a given token ID. The URI is a base64-encoded JSON
    metadata object containing an on-chain SVG image with the token's text
    displayed as white text centered on a black background.

    @param _id The token ID to get the URI for.

    @return _ The token URI as a base64-encoded data URI.
  */
  function tokenURI (
    uint256 _id
  ) external view returns (string memory);

  /**
    Mint a new NFT to the caller with the given `_text` displayed on it. This is
    a faucet function for testing. The token ID is auto-incremented.

    @param _text The text to display on the NFT.

    @return _ The token ID of the newly minted NFT.
  */
  function mint (
    string calldata _text
  ) external returns (uint256);
}


// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { ITest721 } from "./interfaces/ITest721.sol";
import { ERC721 } from "solady/tokens/ERC721.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title A test ERC-721 token.
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A test ERC-721 token with a public faucet mint function. Anyone can mint an
  NFT with custom text to themselves for testing purposes. The NFT art is fully
  onchain as an SVG displaying the white text on a black background.

  @custom:date January 5th, 2026.
*/
contract Test721 is
  ITest721,
  ERC721 {

  /// The next token ID to mint.
  uint256 public nextId;

  /**
    A mapping from token ID to the text stored for that token.

    @custom:param _id The token ID.

    @custom:return _text The text of token `_id`.
  */
  mapping (
    uint256 _id => string _text
  ) public text;

  /**
    Return the name of the token.

    @return _ The name of the token.
  */
  function name () public pure override(ITest721, ERC721) returns (
    string memory
  ) {
    return "Test 721";
  }

  /**
    Returns the symbol of the token.

    @return _ The symbol of the token.
  */
  function symbol () public pure override(ITest721, ERC721) returns (
    string memory
  ) {
    return "TEST721";
  }

  /**
    Returns the token URI for a given token ID. The URI is a base64-encoded JSON
    metadata object containing an on-chain SVG image with the token's text
    displayed as white text centered on a black background.

    @param _id The token ID to get the URI for.

    @return _ The token URI as a base64-encoded data URI.
  */
  function tokenURI (
    uint256 _id
  ) public view override(ITest721, ERC721) returns (string memory) {

    // Ensure the token exists.
    if (!_exists(_id)) {
      revert TokenDoesNotExist();
    }

    // Build the SVG image with the token's text.
    string memory _svg = string(
      abi.encodePacked(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\">",
        "<rect width=\"512\" height=\"512\" fill=\"black\"/>",
        "<text x=\"256\" y=\"256\" fill=\"white\" text-anchor=\"middle\" ",
        "dominant-baseline=\"middle\" font-family=\"monospace\" ",
        "font-size=\"20\">", text[_id], "</text></svg>"
      )
    );

    // Build the JSON metadata.
    string memory _json =
      string(
        abi.encodePacked(
          "{\"name\":\"Test 721 #", LibString.toString(_id), "\",",
          "\"description\":\"A test NFT with onchain art.\",",
          "\"image\":\"data:image/svg+xml;base64,", Base64.encode(bytes(_svg)),
          "\"}"
        )
      );

    // Return as a base64-encoded data URI.
    return string(
      abi.encodePacked(
        "data:application/json;base64,", Base64.encode(bytes(_json))
      )
    );
  }

  /**
    Mint a new NFT to the caller with the given `_text` displayed on it. This is
    a faucet function for testing. The token ID is auto-incremented.

    @param _text The text to display on the NFT.

    @return _ The token ID of the newly minted NFT.
  */
  function mint (
    string calldata _text
  ) external returns (uint256) {
    uint256 _id = nextId++;
    text[_id] = _text;
    _mint(msg.sender, _id);
    return _id;
  }
}


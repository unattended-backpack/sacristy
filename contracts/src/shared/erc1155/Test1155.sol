// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { ITest1155 } from "./interfaces/ITest1155.sol";
import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Test1155
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A test ERC-1155 multi-token with a public faucet mint function. Anyone can
  mint tokens with custom text to themselves for testing purposes. The token art
  is fully on-chain SVG displaying the minted text as black text on a white
  background.

  @custom:date January 5th, 2026.
*/
contract Test1155 is
  ITest1155,
  ERC1155 {

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
  function name () public pure override returns (string memory) {
    return "Test 1155";
  }

  /**
    Returns the symbol of the token.

    @return _ The symbol of the token.
  */
  function symbol () public pure override returns (string memory) {
    return "TEST1155";
  }

  /**
    Returns the URI for a given token ID. The URI is a base64-encoded JSON
    metadata object containing an on-chain SVG image with the token's text
    displayed as black text centered on a white background.

    @param _id The token ID to get the URI for.

    @return _ The token URI as a base64-encoded data URI.
  */
  function uri (
    uint256 _id
  ) public view override(ITest1155, ERC1155) returns (string memory) {

    // Build the SVG image with the token's text.
    string memory _svg =
      string(
        abi.encodePacked(
          "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\">",
          "<rect width=\"512\" height=\"512\" fill=\"white\"/>",
          "<text x=\"256\" y=\"256\" fill=\"black\" text-anchor=\"middle\" ",
          "dominant-baseline=\"middle\" font-family=\"monospace\" ",
          "font-size=\"20\">", text[_id], "</text></svg>"
        )
      );

    // Build the JSON metadata.
    string memory _json =
      string(
        abi.encodePacked(
          "{\"name\":\"Test 1155 #", LibString.toString(_id), "\",",
          "\"description\":\"A test multi-token with on-chain art.\",",
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
  ) external returns (uint256) {
    uint256 _id = nextId++;
    text[_id] = _text;
    _mint(msg.sender, _id, _amount, "");
    return _id;
  }
}


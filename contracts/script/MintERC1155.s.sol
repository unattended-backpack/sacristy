// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { ITest1155 } from "../src/shared/erc1155/interfaces/ITest1155.sol";
import { Script, console } from "forge-std/Script.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Mint ERC-1155
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  Mints test ERC-1155 tokens to each testnet account. Each account mints 10
  fungible tokens with their account name as the displayed text.

  @custom:date January 5th, 2026.
*/
contract MintERC1155 is
  Script {

  /// The Test1155 address (genesis predeploy).
  address constant TEST1155 = 0x0000000000000000000000000000000000001155;

  /// The amount of tokens to mint per account.
  uint256 constant MINT_AMOUNT = 10;

  /// Run this script.
  function run () external {

    // Read configuration from environment.
    string memory _mnemonic = vm.envString("MNEMONIC");
    string memory _accountNamesRaw = vm.envString("ACCOUNT_NAMES");
    string[] memory _accountNames = vm.split(_accountNamesRaw, ",");
    console.log("Mint ERC-1155 Script");
    console.log("  Test1155:", TEST1155);
    console.log("  Amount per account:", MINT_AMOUNT);
    console.log("  Accounts:", _accountNames.length);

    // Mint for each account.
    for (uint32 i = 0; i < _accountNames.length; i++) {
      uint256 _privateKey = vm.deriveKey(_mnemonic, i);
      address _account = vm.addr(_privateKey);
      string memory _name = _accountNames[i];
      console.log("");
      console.log("Minting for account:", _account);
      console.log("  Name:", _name);
      console.log("  Amount:", MINT_AMOUNT);
      vm.startBroadcast(_privateKey);
      uint256 _tokenId = ITest1155(TEST1155).mint(_name, MINT_AMOUNT);
      vm.stopBroadcast();
      console.log("  Token ID:", _tokenId);
    }
    console.log("");
    console.log("ERC-1155 minting complete!");
  }
}


// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { ITest721 } from "../src/shared/erc721/interfaces/ITest721.sol";
import { Script, console } from "forge-std/Script.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Mint ERC-721
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  Mints test ERC-721 NFTs to each testnet account. Each account mints one NFT
  with their account name as the displayed text.

  @custom:date January 5th, 2026.
*/
contract MintERC721 is
  Script {

  /// The Test721 address (genesis predeploy).
  address constant TEST721 = 0x0000000000000000000000000000000000000721;

  /// Run this script.
  function run () external {

    // Read configuration from environment.
    string memory _mnemonic = vm.envString("MNEMONIC");
    string memory _accountNamesRaw = vm.envString("ACCOUNT_NAMES");
    string[] memory _accountNames = vm.split(_accountNamesRaw, ",");
    console.log("Mint ERC-721 Script");
    console.log("  Test721:", TEST721);
    console.log("  Accounts:", _accountNames.length);

    // Mint for each account.
    for (uint32 i = 0; i < _accountNames.length; i++) {
      uint256 _privateKey = vm.deriveKey(_mnemonic, i);
      address _account = vm.addr(_privateKey);
      string memory _name = _accountNames[i];
      console.log("");
      console.log("Minting for account:", _account);
      console.log("  Name:", _name);
      vm.startBroadcast(_privateKey);
      uint256 _tokenId = ITest721(TEST721).mint(_name);
      vm.stopBroadcast();
      console.log("  Token ID:", _tokenId);
    }
    console.log("");
    console.log("ERC-721 minting complete!");
  }
}


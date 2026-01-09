// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { ITest20 } from "../src/shared/erc20/interfaces/ITest20.sol";
import { Script, console } from "forge-std/Script.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Mint ERC-20
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  Mints test ERC-20 tokens to each testnet account. Each account mints 1000
  tokens to themselves via the faucet function.

  @custom:date January 4th, 2026.
*/
contract MintERC20 is
  Script {

  /// The Test20 address (genesis predeploy).
  address constant TEST20 = 0x0000000000000000000000000000000000000020;

  /// The amount to mint (1000 tokens with 18 decimals).
  uint256 constant MINT_AMOUNT = 1000_000000000000000000;

  /// Run this script.
  function run () external {

    // Read configuration from environment.
    string memory _mnemonic = vm.envString("MNEMONIC");
    uint256 _numAccounts = vm.envUint("NUM_ACCOUNTS");
    console.log("Mint ERC-20 Script");
    console.log("  Test20:", TEST20);
    console.log("  Mint:", MINT_AMOUNT);
    console.log("  Accounts:", _numAccounts);

    // Mint for each account.
    for (uint32 i = 0; i < _numAccounts; i++) {
      uint256 _privateKey = vm.deriveKey(_mnemonic, i);
      address _account = vm.addr(_privateKey);
      console.log("");
      console.log("Minting for account:", _account);
      vm.startBroadcast(_privateKey);
      ITest20(TEST20).mint(MINT_AMOUNT);
      vm.stopBroadcast();
    }
    console.log("");
    console.log("ERC-20 minting complete!");
  }
}

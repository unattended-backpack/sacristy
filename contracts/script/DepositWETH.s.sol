// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { IWETH } from "../src/shared/weth/interfaces/IWETH.sol";
import { WithSigner } from "./WithSigner.s.sol";
import { Script, console } from "forge-std/Script.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title WETH Deposit
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  Deposits Ether into WETH for each testnet account. Each account deposits one
  Ether to receive one WETH token.

  @custom:date January 4th, 2026.
*/
contract DepositWETH is
  WithSigner {

  /// The canonical WETH address (same as Ethereum mainnet).
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  /// The amount to deposit (one Ether).
  uint256 constant DEPOSIT_AMOUNT = 1_000000000000000000;

  /**
    Deposit for a specific mnemonic index account.

    @param _index The mnemonic index to deposit for.
  */
  function deposit (
    uint32 _index
  ) internal withSignerIndex(_index) {
    IWETH(WETH).deposit{ value: DEPOSIT_AMOUNT }();
  }

  /// Run this script.
  function run () external {

    // Read configuration from environment.
    uint256 _numAccounts = vm.envUint("NUM_ACCOUNTS");
    console.log("WETH Deposit Script");
    console.log("  WETH:", WETH);
    console.log("  Deposit:", DEPOSIT_AMOUNT);
    console.log("  Accounts:", _numAccounts);

    // Deposit for each account.
    for (uint32 i = 0; i < _numAccounts; i++) {
      deposit(i);
    }
    console.log("");
    console.log("WETH deposits complete!");
  }
}


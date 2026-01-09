// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { ICreateX } from "../src/shared/createx/interfaces/ICreateX.sol";
import { ITest20 } from "../src/shared/erc20/interfaces/ITest20.sol";
import { Test20 } from "../src/shared/erc20/Test20.sol";
import { Script, console } from "forge-std/Script.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Use CreateX
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  Test the CreateX factory by using it to deploy a smart contract.

  @custom:date January 8th, 2026.
*/
contract UseCreateX is
  Script {

  /// This error is emitted if an expected deployment address is incorrect.
  error UnexpectedAddress ();

  /// Run the script.
  function run () external {
    address _CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
    address _EXPECTED_ADDRESS = 0x0000000000004FF483651151c796B2E851cd586e;
    bytes32 _SALT =
      0x7ade446bad517a0120b6fe000000000000000000000000000000000000000000;

    // Read configuration from environment.
    string memory _mnemonic = vm.envString("MNEMONIC");
    console.log("Use CreateX Script");
    console.log("  CreateX:", _CREATEX);

    // Deploy from the first account.
    uint256 _privateKey = vm.deriveKey(_mnemonic, 0);
    address _account = vm.addr(_privateKey);
    console.log("");
    console.log("Deploying from account:", _account);
    vm.startBroadcast(_privateKey);

    // Deploy.
    address _newAddress =
      ICreateX(_CREATEX).deployCreate3(
        _SALT,
        type(Test20).creationCode
      );
    console.log("  - New contract: %s", _newAddress);
    if (_newAddress != _EXPECTED_ADDRESS) {
      revert UnexpectedAddress();
    }

    // Touch the new contract to force explorers to index it.
    ITest20(_newAddress).mint(1);
    console.log("  - Minted 1 token to force indexing");
    vm.stopBroadcast();
    console.log("");
    console.log("CreateX test complete!");
  }
}


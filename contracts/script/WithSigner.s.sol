// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity ^0.8.0;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

/// This error is thrown when no valid signer credentials are provided.
error NoSignerCredentials ();

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title A forge helper script for using a signer.
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A template forge script to find a signer based on environment variables and
  broadcast a function. This makes testing and deployment cleaner. Our hierarchy
  is that an explicit `PRIVATE_KEY` environment variable takes precedent over
  any `MNEMONIC` details and an explicit `MNEMONIC_INDEX` environment variable
  takes precedent over the modifier's provided index.

  @custom:date January 13th, 2026.
*/
contract WithSigner is
  Script {

  /// The address of the signer.
  address internal signer;

  /**
    This function modifier runs the provided function as if it were broadcast
    from a specified signer based on supplied environment variables. Our
    hierarchy is that an explicit `PRIVATE_KEY` environment variable takes
    precedent over any `MNEMONIC` details, including the modifier's provided
    `_index`.

    @param _index The mnemonic index to use when attempting to determine signer.
  */
  modifier withSignerIndex (
    uint32 _index
  ) {

    // Retrieve the signer.
    uint256 _privateKey = vm.envOr("PRIVATE_KEY", uint256(0));
    if (_privateKey == 0) {
      string memory _mnemonic = vm.envString("MNEMONIC");

      // Revert if there is neither a private key nor a mnemonic.
      if (bytes(_mnemonic).length == 0) {
        revert NoSignerCredentials();
      }
      _privateKey = vm.deriveKey(_mnemonic, _index);
    }

    // Broadcast the function with the signer.
    signer = vm.addr(_privateKey);
    console2.log("* signing with", signer);
    vm.startBroadcast(_privateKey);
    _;
    vm.stopBroadcast();
  }

  /**
    This function modifier runs the provided function as if it were broadcast
    from a specified signer based on supplied environment variables. Our
    hierarchy is that an explicit `PRIVATE_KEY` environment variable takes
    precedent over any `MNEMONIC` and `MNEMONIC_INDEX` environment variables.
    This function reverts instead of supporting an optional `_index`.
  */
  modifier withSigner () {

    // Retrieve the signer.
    uint256 _privateKey = vm.envOr("PRIVATE_KEY", uint256(0));
    if (_privateKey == 0) {
      string memory _mnemonic = vm.envString("MNEMONIC");

      // Revert if there is neither a private key nor a mnemonic.
      if (bytes(_mnemonic).length == 0) {
        revert NoSignerCredentials();
      }

      // Revert if there is a mnemonic but no index.
      try vm.envUint("MNEMONIC_INDEX") returns (uint256 _index) {
        _privateKey = vm.deriveKey(_mnemonic, uint32(_index));
      } catch {
        revert NoSignerCredentials();
      }
    }

    // Broadcast the function with the signer.
    signer = vm.addr(_privateKey);
    console2.log("* signing with", signer);
    vm.startBroadcast(_privateKey);
    _;
    vm.stopBroadcast();
  }
}


// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { IDeterministicDeploymentProxy } from
  "./interfaces/IDeterministicDeploymentProxy.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Deterministic Deployment Proxy
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"
  @custom:preserve

  A minimal CREATE2 deployer that accepts `salt ++ initCode` as calldata and
  returns the deployed contract address. This is the canonical "keyless"
  deterministic deployer used by Foundry, Hardhat, and many other tools. This is
  based on Nick Johnson's Yul implementation.

  Calldata format:
  - bytes 0-31: salt (32 bytes)
  - bytes 32+: init code (contract creation bytecode)

  @custom:date January 15th, 2026.
*/
contract DeterministicDeploymentProxy is
  IDeterministicDeploymentProxy {

  /// Deploy a contract using CREATE2. Calldata must be `salt ++ initCode`.
  fallback () external payable {
    assembly {
      let _salt := calldataload(0)
      let _initCodeSize := sub(calldatasize(), 32)
      let _initCode := mload(0x40)
      calldatacopy(_initCode, 32, _initCodeSize)
      let _deployed := create2(callvalue(), _initCode, _initCodeSize, _salt)
      if iszero(_deployed) {
        revert(0, 0)
      }
      mstore(0, _deployed)
      return(12, 20)
    }
  }
}


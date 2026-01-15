// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Deterministic Deployment Proxy Interface
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
interface IDeterministicDeploymentProxy {

  /// Deploy a contract using CREATE2. Calldata must be `salt ++ initCode`.
  fallback () external payable;
}


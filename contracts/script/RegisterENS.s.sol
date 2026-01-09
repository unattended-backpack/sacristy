// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { IENSRegistry } from "../src/l1/ens/interfaces/IENSRegistry.sol";
import { IPublicResolver } from "../src/l1/ens/interfaces/IPublicResolver.sol";
import { IMulticallDelegate } from
  "../src/shared/7702/interfaces/IMulticallDelegate.sol";
import { Utility } from "../src/Utility.sol";
import { Script, console } from "forge-std/Script.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title ENS Registration Script
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  Registers ENS names for testnet accounts via multicall. Accounts must have
  EIP-7702 delegation set up to `MulticallDelegate`. Each account registers
  their name in one transaction using multicall.

  @custom:date December 23rd, 2025.
*/
contract RegisterENS is
  Script {

  // ENS registry contract address.
  address constant REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;

  /// ENS public resolver address.
  address constant RESOLVER = 0xF29100983E058B709F3D539b0c765937B804AC15;

  // The precomputed hash of the `.eth` ENS node.
  bytes32 constant ETH_NODE =
    0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;

  /// The precomputed hash of the `addr.reverse` ENS node.
  bytes32 constant ADDR_REVERSE_NODE =
    0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

  /// Run this script.
  function run () external {

    // Read configuration from environment.
    string memory _mnemonic = vm.envString("MNEMONIC");
    string memory _namesRaw = vm.envString("NAMES");

    // Parse semicolon-separated names.
    string[] memory _names = Utility.splitString(_namesRaw, ";");
    console.log("ENS Registration Script");
    console.log("  Registry:", REGISTRY);
    console.log("  Resolver:", RESOLVER);
    console.log("  Accounts:", _names.length);

    // Register each account's name.
    for (uint32 i = 0; i < _names.length; i++) {
      string memory _name = _names[i];
      if (bytes(_name).length == 0) {
        continue;
      }

      // Broadcast a multicall registration from each account.
      uint256 _privateKey = vm.deriveKey(_mnemonic, i);
      address _account = vm.addr(_privateKey);
      console.log("");
      console.log("Registering:", string.concat(_name, ".eth"));
      console.log("  Account:", _account);
      IMulticallDelegate.Call[] memory _calls =
        _buildRegistrationCalls(_name, _account);
      vm.startBroadcast(_privateKey);
      IMulticallDelegate(_account).multicall(_calls);
      vm.stopBroadcast();
    }
    console.log("");
    console.log("ENS registration complete!");
  }

  /**
    Compute ENS namehash for a label under a parent node.

    @param _parentNode The parent ENS node.
    @param _labelHash The ENS subnode.

    @return _ The combined ENS node.
  */
  function _namehash (
    bytes32 _parentNode,
    bytes32 _labelHash
  ) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(_parentNode, _labelHash));
  }

  /**
    Build all six registration calls for one account.

    @param _name The ENS name to register for an account.
    @param _account The address of the account.

    @return _ The array of ENS-registration calls prepared for multicalling.
  */
  function _buildRegistrationCalls (
    string memory _name,
    address _account
  ) private pure returns (IMulticallDelegate.Call[] memory) {

    // Compute all ENS nodes that need to be registered.
    bytes32 _labelHash = keccak256(bytes(_name));
    bytes32 _nameNode = _namehash(ETH_NODE, _labelHash);
    string memory _addrStr = Utility.addressToString(_account);
    bytes32 _reverseLabelHash = keccak256(bytes(_addrStr));
    bytes32 _reverseNode = _namehash(ADDR_REVERSE_NODE, _reverseLabelHash);

    /*
      Begin building the registration calls.
      Start with forward resolution: name.eth -> address.
      1. Claim the name.eth subnode.
    */
    IMulticallDelegate.Call[] memory _calls = new IMulticallDelegate.Call[](6);
    _calls[0] = IMulticallDelegate.Call({
      value: 0,
      target: REGISTRY,
      data: abi.encodeCall(
        IENSRegistry.setSubnodeOwner, (ETH_NODE, _labelHash, _account)
      )
    });

    // 2. Set the resolver for name.eth.
    _calls[1] = IMulticallDelegate.Call({
      value: 0,
      target: REGISTRY,
      data: abi.encodeCall(IENSRegistry.setResolver, (_nameNode, RESOLVER))
    });

    // 3. Set the address in the resolver.
    _calls[2] = IMulticallDelegate.Call({
      value: 0,
      target: RESOLVER,
      data: abi.encodeCall(IPublicResolver.setAddr, (_nameNode, _account))
    });

    /*
      Reverse resolution: address -> name.eth.
      4. Claim the reverse subnode.
    */
    _calls[3] = IMulticallDelegate.Call({
      value: 0,
      target: REGISTRY,
      data: abi.encodeCall(
        IENSRegistry.setSubnodeOwner,
        (ADDR_REVERSE_NODE, _reverseLabelHash, _account)
      )
    });

    // 5. Set the resolver for the reverse node.
    _calls[4] = IMulticallDelegate.Call({
      value: 0,
      target: REGISTRY,
      data: abi.encodeCall(IENSRegistry.setResolver, (_reverseNode, RESOLVER))
    });

    // 6. Set the name for reverse resolution.
    _calls[5] = IMulticallDelegate.Call({
      value: 0,
      target: RESOLVER,
      data: abi.encodeCall(
        IPublicResolver.setName, (_reverseNode, string.concat(_name, ".eth"))
      )
    });
    return _calls;
  }
}


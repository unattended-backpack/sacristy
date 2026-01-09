// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { IENSRegistry } from "./IENSRegistry.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Minimal Public Resolver Interface
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A simplified ENS resolver supporting address and name resolution.

  @custom:date December 22nd, 2025.
*/
interface IPublicResolver {

  /**
    This resolver is hardcoded to point to the ENS registry address.

    @return _ The address of the ENS registry.
  */
  function ENS () external pure returns (IENSRegistry);

  /**
    Map a specific ENS `_node` to its resolved `_address`.

    @param _node The ENS 32-byte node identifier.

    @return _ The address resolved by the given `_node`.
  */
  function addresses (
    bytes32 _node
  ) external view returns (address);

  /**
    Map a specific ENS `_node` to its resolved `_name`.

    @param _node The ENS 32-byte node identifier.

    @return _ The name of the given `_node`.
  */
  function names (
    bytes32 _node
  ) external view returns (string memory);

  /**
    EIP-165 interface detection.

    @param _interfaceId The EIP-165 interface ID to check for support.

    @return _ Whether `_interfaceId` is supported by this contract.
  */
  function supportsInterface (
    bytes4 _interfaceId
  ) external pure returns (bool);

  /**
    Allow the owner of an ENS node to change its resolved address.

    @param _node The ENS node to update the address of.
    @param _addr The new address to resolve to.
  */
  function setAddr (
    bytes32 _node,
    address _addr
  ) external;

  /**
    Allow the owner of an ENS node to change its resolved name.

    @param _node The ENS node to update the name of.
    @param _name The new name to resolve to.
  */
  function setName (
    bytes32 _node,
    string calldata _name
  ) external;
}

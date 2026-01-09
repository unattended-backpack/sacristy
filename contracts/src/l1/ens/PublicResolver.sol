// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { IENSRegistry } from "./interfaces/IENSRegistry.sol";
import { IPublicResolver } from "./interfaces/IPublicResolver.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Minimal Public Resolver
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A simplified ENS resolver supporting address and name resolution.

  @custom:date December 22nd, 2025.
*/
contract PublicResolver is IPublicResolver {

  /**
    An event emitted whenever a `node` changes its address `addr`.

    @param node The node changing address.
    @param addr The new address of `node`.
  */
  event AddrChanged (
    bytes32 indexed node,
    address addr
  );

  /**
    An event emitted whenever a `node` changes its `name`.

    @param node The node changing name.
    @param name The new name of `node`.
  */
  event NameChanged (
    bytes32 indexed node,
    string name
  );

  /// This resolver is hardcoded to point to the ENS registry address.
  IENSRegistry public constant ENS = IENSRegistry(
    0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e
  );

  /**
    Map a specific ENS `_node` to its resolved `_address`.

    @custom:param _node The ENS 32-byte node identifier.

    @custom:return _ The address resolved by the given `_node`.
  */
  mapping (
    bytes32 _node => address _address
  ) public addresses;

  /**
    Map a specific ENS `_node` to its resolved `_name`.

    @custom:param _node The ENS 32-byte node identifier.

    @custom:return _ The name of the given `_node`.
  */
  mapping (
    bytes32 _node => string _name
  ) public names;

  /**
    A modifier only permitting execution when the caller is owner of `_node`.

    @param _node The ENS node to confirm caller ownership of.
  */
  modifier authorised (
    bytes32 _node
  ) {
    require(ENS.owner(_node) == msg.sender, "not authorized");
    _;
  }

  /**
    EIP-165 interface detection.

    @param _interfaceId The EIP-165 interface ID to check for support.

    @return _ Whether `_interfaceId` is supported by this contract.
  */
  function supportsInterface (
    bytes4 _interfaceId
  ) public pure returns (bool) {
    return _interfaceId == 0x3b3b57de || _interfaceId == 0x691f3431
    || _interfaceId == 0x01ffc9a7;
  }

  /**
    Allow the owner of an ENS node to change its resolved address.

    @param _node The ENS node to update the address of.
    @param _addr The new address to resolve to.
  */
  function setAddr (
    bytes32 _node,
    address _addr
  ) public authorised(_node) {
    addresses[_node] = _addr;
    emit AddrChanged(_node, _addr);
  }

  /**
    Allow the owner of an ENS node to change its resolved name.

    @param _node The ENS node to update the name of.
    @param _name The new name to resolve to.
  */
  function setName (
    bytes32 _node,
    string calldata _name
  ) public authorised(_node) {
    names[_node] = _name;
    emit NameChanged(_node, _name);
  }
}


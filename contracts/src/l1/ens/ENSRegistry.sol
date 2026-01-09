// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

import { IENSRegistry } from "./interfaces/IENSRegistry.sol";

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Minimal ENS Registry
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A simplified ENS registry for local testnets.

  @custom:date December 22nd, 2025.
*/
contract ENSRegistry is
  IENSRegistry {

  /**
    This struct encodes information about ENS node records.

    @param owner The address of the record owner.
    @param resolver The address of the record resolver.
    @param ttl The time-to-live of the record.
  */
  struct Record {
    address owner;
    address resolver;
    uint64 ttl;
  }

  /**
    An event emitted when a `node` (or a subnode `label`) is assigned a new
    owner.

    @param node The node whose ownership has changed.
    @param label The specific label under the `node` whose ownership changed.
    @param owner The new owner of the `node` and `label` pair.
  */
  event NewOwner (
    bytes32 indexed node,
    bytes32 indexed label,
    address owner
  );

  /**
    An event emitted whenever ownership of a `node` is transferred.

    @param node The node whose ownership is transferred.
    @param owner The new owner of the `node`.
  */
  event Transfer (
    bytes32 indexed node,
    address owner
  );

  /**
    An event emitted when a `node` is assigned a new resolver.

    @param node The node whose resolver is changed.
    @param resolver The address of the new resolver.
  */
  event NewResolver (
    bytes32 indexed node,
    address resolver
  );

  /**
    An event emitted when a `node` is assigned a new time-to-live (TTL).

    @param node The node whose time-to-live is changed.
    @param ttl The new time-to-live of the `node`.
  */
  event NewTTL (
    bytes32 indexed node,
    uint64 ttl
  );

  /**
    A mapping from a 32-byte ENS `_node` value to its `Record` of relevant
    ownership and resolution details.

    @custom:param _node The unique identifier of a specific ENS node.

    @custom:return The `Record` of details belonging to the `_node`.
  */
  mapping (
    bytes32 _node => Record _record
  ) public records;

  /**
    Allow callers to register ownership of unowned `_node` `_label` subnode
    pairs. Alternatively, allow the existing owner of a subnode to specify a new
    owner.

    @param _node The ENS base node to operate on.
    @param _label The specific label to produce the subnode of `_node`.
    @param _owner The new owner of the `_node` `_label` subnode.

    @return _ The subnode created from `_node` and `_label`.
  */
  function setSubnodeOwner (
    bytes32 _node,
    bytes32 _label,
    address _owner
  ) external returns (bytes32) {
    bytes32 _subnode = keccak256(abi.encodePacked(_node, _label));
    require(_subnode != bytes32(0), "Frozen root");
    require(
      records[_subnode].owner == address(0)
      || records[_subnode].owner == msg.sender, "Not authorized owner"
    );
    records[_subnode].owner = _owner;
    emit NewOwner(_node, _label, _owner);
    return _subnode;
  }

  /**
    Transfer ownership of an ENS node.

    @param _node The node to transfer ownership of.
    @param _owner The new owner.
  */
  function setOwner (
    bytes32 _node,
    address _owner
  ) external {
    require(records[_node].owner == msg.sender, "Not authorized");
    records[_node].owner = _owner;
    emit Transfer(_node, _owner);
  }

  /**
    Set the resolver of an ENS node.

    @param _node The node to set the new resolver of.
    @param _resolver The address of the new resolver.
  */
  function setResolver (
    bytes32 _node,
    address _resolver
  ) external {
    require(records[_node].owner == msg.sender, "Not authorized");
    records[_node].resolver = _resolver;
    emit NewResolver(_node, _resolver);
  }

  /**
    Set the time-to-live of an ENS node.

    @param _node The node to set the new time-to-live of.
    @param _ttl The new time-to-live.
  */
  function setTTL (
    bytes32 _node,
    uint64 _ttl
  ) external {
    require(records[_node].owner == msg.sender, "Not authorized");
    records[_node].ttl = _ttl;
    emit NewTTL(_node, _ttl);
  }

  /**
    Get the owner of an ENS node.

    @param _node The ENS node to retrieve the owner of.

    @return _ The owner of `_node`.
  */
  function owner (
    bytes32 _node
  ) external view returns (address) {
    return records[_node].owner;
  }

  /**
    Get the resolver of an ENS node.

    @param _node The ENS node to retrieve the resolver of.

    @return _ The resolver of `_node`.
  */
  function resolver (
    bytes32 _node
  ) external view returns (address) {
    return records[_node].resolver;
  }

  /**
    Get the time-to-live of an ENS node.

    @param _node The ENS node to retrieve the time-to-live of.

    @return _ The time-to-live of `_node`.
  */
  function ttl (
    bytes32 _node
  ) external view returns (uint64) {
    return records[_node].ttl;
  }

  /**
    Return whether or not the ENS node `_node` exists.

    @param _node The ENS node to check existence of.

    @return _ Whether or not `_node` exists.
  */
  function recordExists (
    bytes32 _node
  ) external view returns (bool) {
    return records[_node].owner != address(0);
  }
}


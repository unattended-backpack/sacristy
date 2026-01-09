// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Minimal ENS Registry Interface
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A simplified ENS registry for local testnets.

  @custom:date December 22nd, 2025.
*/
interface IENSRegistry {

  /**
    A mapping from a 32-byte ENS `_node` value to its `Record` of relevant
    ownership and resolution details.

    @param _node The unique identifier of a specific ENS node.

    @return _ The `Record` of details belonging to the `_node`.
  */
  function records (
    bytes32 _node
  ) external view returns (address, address, uint64);

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
  ) external returns (bytes32);

  /**
    Transfer ownership of an ENS node.

    @param _node The node to transfer ownership of.
    @param _owner The new owner.
  */
  function setOwner (
    bytes32 _node,
    address _owner
  ) external;

  /**
    Set the resolver of an ENS node.

    @param _node The node to set the new resolver of.
    @param _resolver The address of the new resolver.
  */
  function setResolver (
    bytes32 _node,
    address _resolver
  ) external;

  /**
    Set the time-to-live of an ENS node.

    @param _node The node to set the new time-to-live of.
    @param _ttl The new time-to-live.
  */
  function setTTL (
    bytes32 _node,
    uint64 _ttl
  ) external;

  /**
    Get the owner of an ENS node.

    @param _node The ENS node to retrieve the owner of.

    @return _ The owner of `_node`.
  */
  function owner (
    bytes32 _node
  ) external view returns (address);

  /**
    Get the resolver of an ENS node.

    @param _node The ENS node to retrieve the resolver of.

    @return _ The resolver of `_node`.
  */
  function resolver (
    bytes32 _node
  ) external view returns (address);

  /**
    Get the time-to-live of an ENS node.

    @param _node The ENS node to retrieve the time-to-live of.

    @return _ The time-to-live of `_node`.
  */
  function ttl (
    bytes32 _node
  ) external view returns (uint64);

  /**
    Return whether or not the ENS node `_node` exists.

    @param _node The ENS node to check existence of.

    @return _ Whether or not `_node` exists.
  */
  function recordExists (
    bytes32 _node
  ) external view returns (bool);
}

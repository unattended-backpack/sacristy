// SPDX-License-Identifier: LicenseRef-VPL WITH AGPL-3.0-only
pragma solidity 0.8.33;

/**
  @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVM MEVM
  @title Minimal Universal Resolver Interface
  @author Tim Clancy <tim-clancy.eth>
  @custom:terry "Is this too much voodoo for the next ten centuries?"

  A simplified ENS universal resolver supporting address and name resolution.

  @custom:date January 15th, 2026.
*/
interface IUniversalResolver {

  /**
    An error thrown when a resolver cannot be found for the supplied name.

    @param name The name for which no resolver could be found.
  */
  error ResolverNotFound (
    bytes name
  );

  /**
    An error thrown when a resolver is not a contract.

    @param name The name being resolved.
    @param resolver The address of the resolver.
  */
  error ResolverNotContract (
    bytes name,
    address resolver
  );

  /**
    The resolver did not respond.

    @param selector The function selector.
  */
  error UnsupportedResolverProfile (
    bytes4 selector
  );

  /**
    The resolver returned an error.

    @param errorData The error data.
  */
  error ResolverError (
    bytes errorData
  );

  /**
    The resolved address from reverse resolution does not match the supplied
    address.

    @param primary The resolved name.
    @param primaryAddress The reverse-resolved address.
  */
  error ReverseAddressMismatch (
    string primary,
    bytes primaryAddress
  );

  /**
    Find the resolver address for `_name`.

    @param _name The name to search.

    @return _ A tuple consisting of (the address of the resolver, the namehash
      of `_name`, and the offset into `_name` corresponding to the resolver).
  */
  function findResolver (
    bytes memory _name
  ) external view returns (address, bytes32, uint256);

  /**
    Perform ENS name resolution for the supplied name and resolution data.

    @param _name The name to resolve in normalized DNS-encoded form.
    @param _data The name resolution data.

    @return _ A tuple consisting of (the name resolution result, and the address
      of the resolver used).
  */
  function resolve (
    bytes calldata _name,
    bytes calldata _data
  ) external view returns (bytes memory, address);

  /**
    Perform ENS reverse resolution for the supplied `_address` and `_coinType`.

    @param _address The address to reverse resolve, in encoded form.
    @param _coinType THe coin type to use for the reverse resolution. For
      Ethereum, this is 60. For other EVM chains this is `0x80000000 | chainId`.

    @return _ A tuple consisting of (the reverse resolution result, the address
      of the resolver used to resolve the name, and the address of the resolver
      usued to resolve the reverse name).
  */
  function reverse (
    bytes calldata _address,
    uint256 _coinType
  ) external view returns (string memory, address, address);
}


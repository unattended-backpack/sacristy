// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title AddressManager
/// @notice Legacy contract for managing a registry of string names to addresses.
contract AddressManager {
    address public owner;

    mapping(bytes32 => address) private addresses;

    event AddressSet(string indexed name, address newAddress, address oldAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "AddressManager: caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setAddress(string memory _name, address _address) external onlyOwner {
        bytes32 nameHash = _getNameHash(_name);
        address oldAddress = addresses[nameHash];
        addresses[nameHash] = _address;
        emit AddressSet(_name, _address, oldAddress);
    }

    function getAddress(string memory _name) external view returns (address) {
        return addresses[_getNameHash(_name)];
    }

    function _getNameHash(string memory _name) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_name));
    }
}

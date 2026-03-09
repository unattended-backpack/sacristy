// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Constants } from "src/l2/lib/Constants.sol";

/// @title Proxy
/// @notice Transparent proxy that passes through calls if the caller is not the admin.
contract Proxy {
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    modifier proxyCallIfNotAdmin() {
        if (msg.sender == _getAdmin() || msg.sender == address(0)) {
            _;
        } else {
            _doProxyCall();
        }
    }

    constructor(address _admin) {
        _changeAdmin(_admin);
    }

    receive() external payable { _doProxyCall(); }
    fallback() external payable { _doProxyCall(); }

    function upgradeTo(address _implementation) public virtual proxyCallIfNotAdmin {
        _setImplementation(_implementation);
    }

    function upgradeToAndCall(address _implementation, bytes calldata _data)
        public payable virtual proxyCallIfNotAdmin returns (bytes memory)
    {
        _setImplementation(_implementation);
        (bool success, bytes memory returndata) = _implementation.delegatecall(_data);
        require(success, "Proxy: delegatecall to new implementation contract failed");
        return returndata;
    }

    function changeAdmin(address _admin) public virtual proxyCallIfNotAdmin {
        _changeAdmin(_admin);
    }

    function admin() public virtual proxyCallIfNotAdmin returns (address) {
        return _getAdmin();
    }

    function implementation() public virtual proxyCallIfNotAdmin returns (address) {
        return _getImplementation();
    }

    function _setImplementation(address _implementation) internal {
        bytes32 proxyImplementation = Constants.PROXY_IMPLEMENTATION_ADDRESS;
        assembly { sstore(proxyImplementation, _implementation) }
        emit Upgraded(_implementation);
    }

    function _changeAdmin(address _admin) internal {
        address previous = _getAdmin();
        bytes32 proxyOwner = Constants.PROXY_OWNER_ADDRESS;
        assembly { sstore(proxyOwner, _admin) }
        emit AdminChanged(previous, _admin);
    }

    function _doProxyCall() internal {
        address impl = _getImplementation();
        require(impl != address(0), "Proxy: implementation not initialized");
        assembly {
            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(gas(), impl, 0x0, calldatasize(), 0x0, 0x0)
            returndatacopy(0x0, 0x0, returndatasize())
            if iszero(success) { revert(0x0, returndatasize()) }
            return(0x0, returndatasize())
        }
    }

    function _getImplementation() internal view returns (address) {
        address impl;
        bytes32 proxyImplementation = Constants.PROXY_IMPLEMENTATION_ADDRESS;
        assembly { impl := sload(proxyImplementation) }
        return impl;
    }

    function _getAdmin() internal view returns (address) {
        address owner;
        bytes32 proxyOwner = Constants.PROXY_OWNER_ADDRESS;
        assembly { owner := sload(proxyOwner) }
        return owner;
    }
}

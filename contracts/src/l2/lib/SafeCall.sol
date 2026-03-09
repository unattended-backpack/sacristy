// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SafeCall
/// @notice Perform low level safe calls.
library SafeCall {
    /// @notice Perform a low level call without copying any returndata.
    function send(address _target, uint256 _gas, uint256 _value) internal returns (bool success_) {
        assembly {
            success_ := call(_gas, _target, _value, 0, 0, 0, 0)
        }
    }

    /// @notice Perform a low level call without copying any returndata.
    function call(
        address _target,
        uint256 _gas,
        uint256 _value,
        bytes memory _calldata
    ) internal returns (bool success_) {
        assembly {
            success_ := call(_gas, _target, _value, add(_calldata, 32), mload(_calldata), 0, 0)
        }
    }

    /// @notice Helper to determine if there is sufficient gas for a call.
    function hasMinGas(uint256 _minGas, uint256 _reservedGas) internal view returns (bool) {
        bool _hasMinGas;
        assembly {
            _hasMinGas := iszero(lt(mul(gas(), 63), add(mul(_minGas, 64), mul(add(40000, _reservedGas), 63))))
        }
        return _hasMinGas;
    }

    /// @notice Perform a low level call with minimum gas guarantee.
    function callWithMinGas(
        address _target,
        uint256 _minGas,
        uint256 _value,
        bytes memory _calldata
    ) internal returns (bool) {
        bool _success;
        bool _hasMinGas = hasMinGas(_minGas, 0);
        assembly {
            if iszero(_hasMinGas) {
                mstore(0, 0x08c379a0)
                mstore(32, 32)
                mstore(88, 0x0000185361666543616c6c3a204e6f7420656e6f75676820676173)
                revert(28, 100)
            }
            _success := call(gas(), _target, _value, add(_calldata, 32), mload(_calldata), 0x00, 0x00)
        }
        return _success;
    }
}

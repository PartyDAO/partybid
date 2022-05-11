// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/structs/EnumerableSetUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

// Bytes32Set
contract EnumerableBytes32SetMockUpgradeable is Initializable {
    function __EnumerableBytes32SetMock_init() internal initializer {
        __EnumerableBytes32SetMock_init_unchained();
    }

    function __EnumerableBytes32SetMock_init_unchained() internal initializer {
    }
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    event OperationResult(bool result);

    EnumerableSetUpgradeable.Bytes32Set private _set;

    function contains(bytes32 value) public view returns (bool) {
        return _set.contains(value);
    }

    function add(bytes32 value) public {
        bool result = _set.add(value);
        emit OperationResult(result);
    }

    function remove(bytes32 value) public {
        bool result = _set.remove(value);
        emit OperationResult(result);
    }

    function length() public view returns (uint256) {
        return _set.length();
    }

    function at(uint256 index) public view returns (bytes32) {
        return _set.at(index);
    }
    uint256[48] private __gap;
}

// AddressSet
contract EnumerableAddressSetMockUpgradeable is Initializable {
    function __EnumerableAddressSetMock_init() internal initializer {
        __EnumerableAddressSetMock_init_unchained();
    }

    function __EnumerableAddressSetMock_init_unchained() internal initializer {
    }
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    event OperationResult(bool result);

    EnumerableSetUpgradeable.AddressSet private _set;

    function contains(address value) public view returns (bool) {
        return _set.contains(value);
    }

    function add(address value) public {
        bool result = _set.add(value);
        emit OperationResult(result);
    }

    function remove(address value) public {
        bool result = _set.remove(value);
        emit OperationResult(result);
    }

    function length() public view returns (uint256) {
        return _set.length();
    }

    function at(uint256 index) public view returns (address) {
        return _set.at(index);
    }
    uint256[48] private __gap;
}

// UintSet
contract EnumerableUintSetMockUpgradeable is Initializable {
    function __EnumerableUintSetMock_init() internal initializer {
        __EnumerableUintSetMock_init_unchained();
    }

    function __EnumerableUintSetMock_init_unchained() internal initializer {
    }
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    event OperationResult(bool result);

    EnumerableSetUpgradeable.UintSet private _set;

    function contains(uint256 value) public view returns (bool) {
        return _set.contains(value);
    }

    function add(uint256 value) public {
        bool result = _set.add(value);
        emit OperationResult(result);
    }

    function remove(uint256 value) public {
        bool result = _set.remove(value);
        emit OperationResult(result);
    }

    function length() public view returns (uint256) {
        return _set.length();
    }

    function at(uint256 index) public view returns (uint256) {
        return _set.at(index);
    }
    uint256[48] private __gap;
}

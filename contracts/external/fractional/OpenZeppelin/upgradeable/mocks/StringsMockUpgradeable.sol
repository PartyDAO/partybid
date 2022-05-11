// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/StringsUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

contract StringsMockUpgradeable is Initializable {
    function __StringsMock_init() internal initializer {
        __StringsMock_init_unchained();
    }

    function __StringsMock_init_unchained() internal initializer {
    }
    function fromUint256(uint256 value) public pure returns (string memory) {
        return StringsUpgradeable.toString(value);
    }

    function fromUint256Hex(uint256 value) public pure returns (string memory) {
        return StringsUpgradeable.toHexString(value);
    }

    function fromUint256HexFixed(uint256 value, uint256 length) public pure returns (string memory) {
        return StringsUpgradeable.toHexString(value, length);
    }
    uint256[50] private __gap;
}

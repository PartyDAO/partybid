// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/math/MathUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

contract MathMockUpgradeable is Initializable {
    function __MathMock_init() internal initializer {
        __MathMock_init_unchained();
    }

    function __MathMock_init_unchained() internal initializer {
    }
    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return MathUpgradeable.max(a, b);
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return MathUpgradeable.min(a, b);
    }

    function average(uint256 a, uint256 b) public pure returns (uint256) {
        return MathUpgradeable.average(a, b);
    }

    function ceilDiv(uint256 a, uint256 b) public pure returns (uint256) {
        return MathUpgradeable.ceilDiv(a, b);
    }
    uint256[50] private __gap;
}

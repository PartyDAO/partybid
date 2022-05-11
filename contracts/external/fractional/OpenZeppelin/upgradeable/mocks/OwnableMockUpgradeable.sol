// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../access/OwnableUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

contract OwnableMockUpgradeable is Initializable, OwnableUpgradeable {    function __OwnableMock_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __OwnableMock_init_unchained();
    }

    function __OwnableMock_init_unchained() internal initializer {
    }
    uint256[50] private __gap;
}

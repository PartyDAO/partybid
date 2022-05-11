// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../token/ERC20/extensions/ERC20WrapperUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

contract ERC20WrapperMockUpgradeable is Initializable, ERC20WrapperUpgradeable {
    function __ERC20WrapperMock_init(
        IERC20Upgradeable _underlyingToken,
        string memory name,
        string memory symbol
    ) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Wrapper_init_unchained(_underlyingToken);
        __ERC20WrapperMock_init_unchained(_underlyingToken, name, symbol);
    }

    function __ERC20WrapperMock_init_unchained(
        IERC20Upgradeable _underlyingToken,
        string memory name,
        string memory symbol
    ) internal initializer {}

    function recover(address account) public returns (uint256) {
        return _recover(account);
    }
    uint256[50] private __gap;
}

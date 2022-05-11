// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../token/ERC20/extensions/ERC20FlashMintUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

contract ERC20FlashMintMockUpgradeable is Initializable, ERC20FlashMintUpgradeable {
    function __ERC20FlashMintMock_init(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    ) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20FlashMint_init_unchained();
        __ERC20FlashMintMock_init_unchained(name, symbol, initialAccount, initialBalance);
    }

    function __ERC20FlashMintMock_init_unchained(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    ) internal initializer {
        _mint(initialAccount, initialBalance);
    }
    uint256[50] private __gap;
}

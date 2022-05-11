// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @title ERC721PausableMock
 * This mock just provides a public mint, burn and exists functions for testing purposes
 */
contract ERC721PausableMockUpgradeable is Initializable, ERC721PausableUpgradeable {
    function __ERC721PausableMock_init(string memory name, string memory symbol) internal initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC721_init_unchained(name, symbol);
        __Pausable_init_unchained();
        __ERC721Pausable_init_unchained();
        __ERC721PausableMock_init_unchained(name, symbol);
    }

    function __ERC721PausableMock_init_unchained(string memory name, string memory symbol) internal initializer {}

    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public {
        _safeMint(to, tokenId, _data);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }
    uint256[50] private __gap;
}

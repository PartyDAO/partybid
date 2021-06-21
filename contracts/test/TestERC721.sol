// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    constructor() ERC721("TestNFT", "tNFT") {} // solhint-disable-line no-empty-blocks

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
